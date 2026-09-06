from __future__ import annotations

import json
import os
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

load_dotenv()

APP_DIR = Path(__file__).resolve().parent
DB_PATH = Path(os.getenv("EDGESPACE_DB_PATH", APP_DIR / "data" / "edgespace.db"))
DB_PATH.parent.mkdir(parents=True, exist_ok=True)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-3.8-flash").strip()

app = FastAPI(
    title="EdgeSpace AI Backend",
    version="0.1.0",
    description="Local backend for EdgeSpace AI, telemetry storage and Gemini assistant.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# DATABASE
# ============================================================

@contextmanager
def db():
    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    try:
        yield connection
        connection.commit()
    finally:
        connection.close()


def init_db() -> None:
    with db() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS devices (
                device_id TEXT PRIMARY KEY,
                room_id TEXT NOT NULL,
                name TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS telemetry (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id TEXT,
                room_id TEXT NOT NULL,
                ts TEXT NOT NULL,
                temperature REAL,
                humidity REAL,
                motion INTEGER,
                noise REAL
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_telemetry_room_ts "
            "ON telemetry(room_id, ts DESC)"
        )


@app.on_event("startup")
def on_startup() -> None:
    init_db()


# ============================================================
# MODELS
# ============================================================

class DeviceRegistration(BaseModel):
    device_id: str = Field(min_length=1)
    room_id: str = Field(min_length=1)
    name: str | None = None


class TelemetryIn(BaseModel):
    device_id: str | None = None
    room_id: str = Field(min_length=1)
    ts: str | None = None
    temperature: float | None = None
    humidity: float | None = None
    motion: bool | int | None = None
    noise: float | None = None


class ConversationMessage(BaseModel):
    role: str
    text: str


class AiChatRequest(BaseModel):
    question: str = Field(min_length=1)
    room_id: str | None = None
    app_context: str | None = None
    conversation: list[ConversationMessage] = []


# ============================================================
# HELPERS
# ============================================================

def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def telemetry_row(row: sqlite3.Row) -> dict[str, Any]:
    motion = row["motion"]
    return {
        "ts": row["ts"],
        "temperature": row["temperature"],
        "humidity": row["humidity"],
        "motion": None if motion is None else bool(motion),
        "noise": row["noise"],
    }


def build_system_instruction(app_context: str | None) -> str:
    context = (app_context or "").strip()

    return f"""
You are EdgeSpace AI Assistant, the built-in intelligent assistant of the EdgeSpace AI application.

Behavior:
- Reply naturally and conversationally, not like a command menu.
- Reply in the same language as the user. If the user writes Greek, answer in Greek.
- You can answer BOTH questions about EdgeSpace AI and normal/general questions.
- For EdgeSpace AI questions, use the application context below as the authoritative source.
- Guide the user step-by-step when they ask how to use the app.
- Use conversation history to understand short follow-up questions such as "και μετά;", "μόνο αυτό;", "δώσε μου παράδειγμα".
- Never invent current sensor values, rooms, devices, alerts, or app state. If the needed value is not in the context, say that it is not currently available.
- If the user asks for analysis of room data, explain the conclusion clearly and mention the relevant measurements when available.
- Your name is "EdgeSpace AI Assistant".
- Be concise by default, but give enough detail to be useful.

CURRENT EDGESPACE APPLICATION CONTEXT:
{context if context else "(No live application context was supplied for this request.)"}
""".strip()


def build_contents(req: AiChatRequest) -> list[dict[str, Any]]:
    contents: list[dict[str, Any]] = []

    for msg in req.conversation[-12:]:
        role = "model" if msg.role.lower() in {"assistant", "model"} else "user"
        text = msg.text.strip()
        if text:
            contents.append(
                {
                    "role": role,
                    "parts": [{"text": text}],
                }
            )

    # Avoid duplicating the newest question if the Flutter app already included it
    # as the last conversation message.
    if not contents or contents[-1]["role"] != "user" or contents[-1]["parts"][0]["text"] != req.question.strip():
        contents.append(
            {
                "role": "user",
                "parts": [{"text": req.question.strip()}],
            }
        )

    return contents


async def ask_gemini(req: AiChatRequest) -> str:
    if not GEMINI_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="Gemini is not configured. Set GEMINI_API_KEY in backend/.env.",
        )

    url = (
        "https://generativelanguage.googleapis.com/v1beta/"
        f"models/{GEMINI_MODEL}:generateContent"
    )

    payload = {
        "systemInstruction": {
            "parts": [
                {
                    "text": build_system_instruction(req.app_context),
                }
            ]
        },
        "contents": build_contents(req),
        "generationConfig": {
            "temperature": 0.6,
            "maxOutputTokens": 2048,
        },
    }

    headers = {
        "Content-Type": "application/json",
        "x-goog-api-key": GEMINI_API_KEY,
    }

    try:
        async with httpx.AsyncClient(timeout=45.0) as client:
            response = await client.post(url, headers=headers, json=payload)
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Could not reach Gemini API: {exc}",
        ) from exc

    if response.status_code >= 300:
        detail = response.text
        try:
            body = response.json()
            detail = body.get("error", {}).get("message", detail)
        except Exception:
            pass
        raise HTTPException(
            status_code=502,
            detail=f"Gemini API error ({response.status_code}): {detail}",
        )

    body = response.json()
    candidates = body.get("candidates") or []
    if not candidates:
        raise HTTPException(status_code=502, detail="Gemini returned no candidate.")

    parts = candidates[0].get("content", {}).get("parts", [])
    text = "\n".join(
        str(part.get("text", "")).strip()
        for part in parts
        if part.get("text")
    ).strip()

    if not text:
        raise HTTPException(status_code=502, detail="Gemini returned an empty answer.")

    return text


# ============================================================
# ROUTES
# ============================================================

@app.get("/")
def root() -> dict[str, Any]:
    return {
        "service": "EdgeSpace AI Backend",
        "status": "online",
        "gemini_configured": bool(GEMINI_API_KEY),
        "gemini_model": GEMINI_MODEL,
    }


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "ok": True,
        "service": "EdgeSpace AI Backend",
        "gemini_configured": bool(GEMINI_API_KEY),
        "gemini_model": GEMINI_MODEL,
    }


@app.post("/api/v1/devices/register")
def register_device(req: DeviceRegistration) -> dict[str, Any]:
    now = utc_now_iso()
    with db() as conn:
        conn.execute(
            """
            INSERT INTO devices(device_id, room_id, name, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(device_id) DO UPDATE SET
                room_id=excluded.room_id,
                name=excluded.name,
                updated_at=excluded.updated_at
            """,
            (req.device_id, req.room_id, req.name, now, now),
        )

    return {
        "ok": True,
        "device_id": req.device_id,
        "room_id": req.room_id,
    }


@app.post("/api/v1/telemetry")
def ingest_telemetry(req: TelemetryIn) -> dict[str, Any]:
    ts = req.ts or utc_now_iso()
    motion_value = None if req.motion is None else int(bool(req.motion))

    with db() as conn:
        conn.execute(
            """
            INSERT INTO telemetry(
                device_id, room_id, ts,
                temperature, humidity, motion, noise
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                req.device_id,
                req.room_id,
                ts,
                req.temperature,
                req.humidity,
                motion_value,
                req.noise,
            ),
        )

        if req.device_id:
            now = utc_now_iso()
            conn.execute(
                """
                UPDATE devices
                SET room_id=?, updated_at=?
                WHERE device_id=?
                """,
                (req.room_id, now, req.device_id),
            )

    return {"ok": True, "ts": ts}


@app.get("/api/v1/rooms/{room_id}/latest")
def latest_telemetry(room_id: str) -> dict[str, Any]:
    with db() as conn:
        row = conn.execute(
            """
            SELECT ts, temperature, humidity, motion, noise
            FROM telemetry
            WHERE room_id=?
            ORDER BY ts DESC
            LIMIT 1
            """,
            (room_id,),
        ).fetchone()

    if row is None:
        raise HTTPException(status_code=404, detail="No telemetry for this room.")

    return telemetry_row(row)


@app.get("/api/v1/rooms/{room_id}/telemetry")
def telemetry_history(
    room_id: str,
    hours: int = Query(default=24, ge=1, le=24 * 90),
) -> list[dict[str, Any]]:
    # SQLite's datetime() can compare ISO timestamps if normalized, but for this
    # prototype it is safer to fetch recent room rows and filter in Python.
    cutoff = datetime.now(timezone.utc).timestamp() - (hours * 3600)

    with db() as conn:
        rows = conn.execute(
            """
            SELECT ts, temperature, humidity, motion, noise
            FROM telemetry
            WHERE room_id=?
            ORDER BY ts ASC
            """,
            (room_id,),
        ).fetchall()

    result: list[dict[str, Any]] = []
    for row in rows:
        try:
            parsed = datetime.fromisoformat(str(row["ts"]).replace("Z", "+00:00"))
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone.utc)
            if parsed.timestamp() < cutoff:
                continue
        except Exception:
            pass
        result.append(telemetry_row(row))

    return result


@app.post("/api/v1/ai/chat")
async def ai_chat(req: AiChatRequest) -> dict[str, Any]:
    answer = await ask_gemini(req)
    return {
        "answer": answer,
        "model": GEMINI_MODEL,
    }
