from __future__ import annotations

from dataclasses import dataclass
from math import sqrt
from statistics import mean


@dataclass
class Insight:
    title: str
    body: str
    severity: str


def linear_slope(values: list[float]) -> float:
    if len(values) < 2:
        return 0.0
    n = float(len(values))
    sx = sum(range(len(values)))
    sy = sum(values)
    sxy = sum(i * v for i, v in enumerate(values))
    sx2 = sum(i * i for i in range(len(values)))
    denom = n * sx2 - sx * sx
    return 0.0 if denom == 0 else (n * sxy - sx * sy) / denom


def z_score_latest(values: list[float]) -> float:
    if len(values) < 4:
        return 0.0
    m = mean(values)
    variance = sum((x - m) ** 2 for x in values) / len(values)
    std = sqrt(variance)
    return 0.0 if std == 0 else (values[-1] - m) / std


def room_score(latest: dict[str, float]) -> int:
    score = 100
    t = latest.get("temperature")
    h = latest.get("humidity")
    n = latest.get("noise")
    if t is not None:
        if t < 19 or t > 28:
            score -= 18
        if t < 16 or t > 31:
            score -= 18
    if h is not None:
        if h < 30 or h > 65:
            score -= 15
        if h < 20 or h > 75:
            score -= 12
    if n is not None:
        if n > 650:
            score -= 16
        if n > 850:
            score -= 14
    return max(0, min(100, score))


def analyze_series(series: dict[str, list[float]]) -> list[Insight]:
    out: list[Insight] = []
    temp = series.get("temperature", [])[-12:]
    hum = series.get("humidity", [])[-12:]
    noise = series.get("noise", [])[-12:]

    if temp:
        if temp[-1] > 28:
            out.append(Insight("High temperature", f"Latest temperature is {temp[-1]:.1f}°C.", "warning"))
        if linear_slope(temp) > 0.08:
            out.append(Insight("Temperature rising", "Temperature has a persistent upward trend in the latest samples.", "info"))
        if abs(z_score_latest(temp)) > 2.2:
            out.append(Insight("Temperature anomaly", "Latest temperature differs strongly from the recent room profile.", "warning"))

    if hum:
        if hum[-1] > 65:
            out.append(Insight("High humidity", f"Latest humidity is {hum[-1]:.0f}%.", "warning"))
        if abs(z_score_latest(hum)) > 2.2:
            out.append(Insight("Humidity anomaly", "Latest humidity differs strongly from the recent room profile.", "warning"))

    if noise:
        if noise[-1] > 700:
            out.append(Insight("Elevated noise", "Noise is elevated compared with the preferred operating range.", "warning"))
        if abs(z_score_latest(noise)) > 2.2:
            out.append(Insight("Noise anomaly", "Latest noise level is unusual for this room's recent pattern.", "warning"))

    if not out:
        out.append(Insight("Conditions stable", "No significant anomalies were detected in the latest sensor history.", "info"))
    return out
