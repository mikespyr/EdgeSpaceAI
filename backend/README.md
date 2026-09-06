# EdgeSpace AI Backend

This backend is designed to match the current Flutter `ApiClient`.

## Expected Flutter URL on the physical Samsung

```text
http://10.25.143.167:8000
```

`10.25.143.167` is the Wi-Fi IPv4 of the development PC.

The phone and PC must be reachable on the same local network. Some university / guest Wi-Fi networks block device-to-device traffic (AP/client isolation). If that happens, use a normal home router or a phone hotspot / local LAN where devices can reach each other.

## 1. Create the Gemini key

Create a Gemini API key in Google AI Studio, then copy:

```text
.env.example
```

to:

```text
.env
```

and replace:

```text
PASTE_YOUR_GEMINI_API_KEY_HERE
```

with the key.

Never place the Gemini API key inside Flutter or the ESP32 firmware.

## 2. Start backend

From this folder:

```powershell
.\start_backend.ps1
```

The server binds to:

```text
0.0.0.0:8000
```

so other devices on the LAN can connect.

## 3. Test on the PC

Open:

```text
http://127.0.0.1:8000/health
```

or run:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

Expected:

```json
{
  "ok": true,
  "service": "EdgeSpace AI Backend",
  "gemini_configured": true,
  "gemini_model": "gemini-3.8-flash"
}
```

## 4. Test from the Samsung

While the backend is running, open in the phone browser:

```text
http://10.25.143.167:8000/health
```

If the JSON appears, phone -> PC networking is working.

## 5. Configure EdgeSpace AI

Settings -> Backend URL:

```text
http://10.25.143.167:8000
```

Keep `Gemini AI Advisor` enabled and tap `Save Settings`.

The Settings badge should become `Backend Online`.

## API routes

- `GET /health`
- `POST /api/v1/devices/register`
- `POST /api/v1/telemetry`
- `GET /api/v1/rooms/{room_id}/latest`
- `GET /api/v1/rooms/{room_id}/telemetry?hours=24`
- `POST /api/v1/ai/chat`

## ESP32 telemetry JSON example

```json
{
  "device_id": "edge-c3-001",
  "room_id": "r123",
  "temperature": 23.4,
  "humidity": 51.2,
  "motion": true,
  "noise": 420
}
```
