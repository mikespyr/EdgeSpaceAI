from __future__ import annotations

import json
import os
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from .analytics import analyze_series, room_score

load_dotenv()
DB_PATH = Path(os.environ.get("EDGESPACE_DB", "edgespace.db"))

app = FastAPI(title="EdgeSpace AI API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Development only. Restrict this in production.
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class RegisterDevice(BaseModel):
    device_id: str = Field(min_length=3, max_length=100)
    room_id: str = Field(min_length=1, max_length=100)
    name: str | None = None


class Telemetry(BaseModel):
    device_id: str
    room_id: str
    temperature: float | None = None
    humidity: float | None = None
    motion: bool | None = None
    noise: float | None = None
    rssi: int | None = None
    ts: datetime | None = None


class AiChatRequest(BaseModel):
    question: str = Field(min_length=1, max_length=4000)
    room_id: str | None = None


def db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with db() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS devices (
                device_id TEXT PRIMARY KEY,
                room_id TEXT NOT NULL,
                name TEXT,
                firmware TEXT,
                last_seen TEXT
            );
            CREATE TABLE IF NOT EXISTS telemetry (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id TEXT NOT NULL,
                room_id TEXT NOT NULL,
                ts TEXT NOT NULL,
                temperature REAL,
                humidity REAL,
                motion INTEGER,
                noise REAL,
                rssi INTEGER
            );
            CREATE INDEX IF NOT EXISTS idx_telemetry_room_ts ON telemetry(room_id, ts);
            """
        )


@app.on_event("startup")
def startup() -> None:
    init_db()


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "gemini_configured": bool(os.environ.get("GEMINI_API_KEY")),
        "model": os.environ.get("GEMINI_MODEL", "gemini-3.8-flash"),
    }


@app.post("/api/v1/devices/register")
def register_device(body: RegisterDevice) -> dict[str, Any]:
    now = datetime.now(timezone.utc).isoformat()
    with db() as conn:
        conn.execute(
            """
            INSERT INTO devices(device_id, room_id, name, last_seen)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(device_id) DO UPDATE SET
                room_id=excluded.room_id,
                name=excluded.name,
                last_seen=excluded.last_seen
            """,
            (body.device_id, body.room_id, body.name, now),
        )
    return {"ok": True, "device_id": body.device_id, "room_id": body.room_id}


@app.post("/api/v1/telemetry")
def ingest(body: Telemetry) -> dict[str, Any]:
    ts = (body.ts or datetime.now(timezone.utc)).astimezone(timezone.utc).isoformat()
    with db() as conn:
        device = conn.execute("SELECT * FROM devices WHERE device_id=?", (body.device_id,)).fetchone()
        if device is None:
            conn.execute(
                "INSERT INTO devices(device_id, room_id, name, last_seen) VALUES (?, ?, ?, ?)",
                (body.device_id, body.room_id, body.device_id, ts),
            )
        conn.execute(
            """
            INSERT INTO telemetry(device_id, room_id, ts, temperature, humidity, motion, noise, rssi)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                body.device_id,
                body.room_id,
                ts,
                body.temperature,
                body.humidity,
                None if body.motion is None else int(body.motion),
                body.noise,
                body.rssi,
            ),
        )
        conn.execute("UPDATE devices SET room_id=?, last_seen=? WHERE device_id=?", (body.room_id, ts, body.device_id))
    return {"ok": True, "received_at": ts}


@app.get("/api/v1/devices")
def devices() -> list[dict[str, Any]]:
    with db() as conn:
        rows = conn.execute("SELECT * FROM devices ORDER BY device_id").fetchall()
    return [dict(r) for r in rows]


@app.get("/api/v1/rooms/{room_id}/telemetry")
def room_telemetry(room_id: str, hours: int = Query(24, ge=1, le=24 * 30)) -> list[dict[str, Any]]:
    start = (datetime.now(timezone.utc) - timedelta(hours=hours)).isoformat()
    with db() as conn:
        rows = conn.execute("SELECT * FROM telemetry WHERE room_id=? AND ts>=? ORDER BY ts", (room_id, start)).fetchall()
    return [dict(r) for r in rows]


@app.get("/api/v1/rooms/{room_id}/latest")
def latest_telemetry(room_id: str) -> dict[str, Any]:
    with db() as conn:
        row = conn.execute("SELECT * FROM telemetry WHERE room_id=? ORDER BY ts DESC LIMIT 1", (room_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="No telemetry for room")
    return dict(row)


@app.get("/api/v1/rooms/{room_id}/analytics")
def analytics(room_id: str, hours: int = Query(24, ge=1, le=24 * 30)) -> dict[str, Any]:
    rows = room_telemetry(room_id, hours)
    if not rows:
        raise HTTPException(status_code=404, detail="No telemetry for room")
    return build_room_context(room_id, rows)


def build_room_context(room_id: str, rows: list[dict[str, Any]]) -> dict[str, Any]:
    keys = ["temperature", "humidity", "noise"]
    series: dict[str, list[float]] = {k: [] for k in keys}
    latest: dict[str, Any] = {}
    motion: bool | None = None
    for row in rows:
        for key in keys:
            value = row.get(key)
            if value is not None:
                series[key].append(float(value))
                latest[key] = float(value)
        if row.get("motion") is not None:
            motion = bool(row["motion"])
    latest["motion"] = motion
    insights = analyze_series(series)
    summary: dict[str, Any] = {}
    for key, values in series.items():
        if values:
            summary[key] = {
                "latest": values[-1],
                "average": sum(values) / len(values),
                "minimum": min(values),
                "maximum": max(values),
                "samples": len(values),
            }
    return {
        "room_id": room_id,
        "score": room_score({k: v for k, v in latest.items() if isinstance(v, (int, float))}),
        "latest": latest,
        "summary": summary,
        "insights": [i.__dict__ for i in insights],
        "samples": len(rows),
    }


def ai_context(room_id: str | None) -> dict[str, Any]:
    start = (datetime.now(timezone.utc) - timedelta(hours=24)).isoformat()
    with db() as conn:
        if room_id:
            rows = conn.execute("SELECT * FROM telemetry WHERE room_id=? AND ts>=? ORDER BY ts", (room_id, start)).fetchall()
            return {"scope": room_id, "rooms": [build_room_context(room_id, [dict(r) for r in rows])] if rows else []}

        room_rows = conn.execute("SELECT DISTINCT room_id FROM telemetry WHERE ts>=?", (start,)).fetchall()
        contexts = []
        for room in room_rows:
            rid = room["room_id"]
            rows = conn.execute("SELECT * FROM telemetry WHERE room_id=? AND ts>=? ORDER BY ts", (rid, start)).fetchall()
            if rows:
                contexts.append(build_room_context(rid, [dict(r) for r in rows]))
        return {"scope": "all", "rooms": contexts}


@app.post("/api/v1/ai/chat")
def ai_chat(body: AiChatRequest) -> dict[str, Any]:
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="GEMINI_API_KEY is not configured on the backend")

    from google import genai

    context = ai_context(body.room_id)
    model = os.environ.get("GEMINI_MODEL", "gemini-3.8-flash")
    system_rules = """
You are EdgeSpace AI, an assistant for indoor environmental monitoring.
Use ONLY the supplied EdgeSpace sensor context for factual claims about rooms.
Do not invent measurements. If context is missing, say that data is unavailable.
Prioritize concise, actionable recommendations and explain which sensor values or trends support them.
The current prototype sensors are temperature, humidity, PIR motion/activity and a relative analog noise level; do not treat the noise value as calibrated dB unless explicitly provided.
Reply in Greek when the user writes in Greek; otherwise reply in the user's language.
This tool provides operational suggestions, not medical or life-safety guarantees.
""".strip()
    prompt = f"{system_rules}\n\nEDGESPACE CONTEXT (last 24h):\n{json.dumps(context, ensure_ascii=False)}\n\nUSER QUESTION:\n{body.question}"

    try:
        client = genai.Client(api_key=api_key)
        response = client.models.generate_content(model=model, contents=prompt)
        answer = (response.text or "").strip()
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Gemini request failed: {exc}") from exc

    if not answer:
        raise HTTPException(status_code=502, detail="Gemini returned an empty response")
    return {"answer": answer, "model": model, "scope": context["scope"]}
