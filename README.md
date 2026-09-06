# EdgeSpace AI — Conference Prototype

A Flutter + ESP32-C3 + FastAPI platform for multi-space IoT monitoring, analytics, BLE onboarding and AI-assisted decision support.

## UI direction
The Flutter UI follows `docs/EdgeSpaceAI_mockup.png`:
1. Welcome / brand screen
2. Dashboard overview
3. Buildings & rooms
4. Room live status
5. Room historical charts
6. AI insights
7. Bluetooth device onboarding
8. Wi-Fi configuration
9. Cross-room analytics & filters
10. AI chat assistant

## Project structure

```text
EdgeSpaceAI_Conference_App/
├── flutter_app/
├── backend/
├── esp32/
└── docs/
```

## AI architecture

The Gemini API key is intentionally **not** stored in the Flutter app or ESP32 firmware.

```text
Flutter -> EdgeSpace Backend -> Gemini API
             ^
             |
ESP32-C3 -> telemetry database
```

The backend builds a sensor context from the last 24 hours and gives Gemini only the relevant measurements, room score and deterministic anomaly/trend analysis. If Gemini is unavailable, the Flutter app falls back to a local deterministic advisor.

## Start the backend

Windows PowerShell:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
# edit .env and paste a NEW Gemini key
.\run.ps1
```

Or run `setup_gemini_key.ps1` to create the local `.env` file interactively.

The backend starts on port `8000`.

## Create Flutter platform folders

Flutter SDK is required on your computer.

```powershell
cd flutter_app
.\bootstrap_platforms.ps1
```

Then apply `PLATFORM_PERMISSIONS.md`, run:

```powershell
flutter pub get
flutter run
```

Android emulator backend URL: `http://10.0.2.2:8000`

Physical Android phone: replace the backend URL in Settings with your PC's LAN IP, e.g. `http://192.168.1.50:8000`.

## Real device onboarding

1. Flash `esp32/EdgeSpaceNode/EdgeSpaceNode.ino` to ESP32-C3.
2. Open EdgeSpace AI > Settings > Connect New Kit.
3. Scan BLE.
4. Select the ESP32-C3.
5. Choose the target room.
6. Enter Wi-Fi credentials.
7. The app writes Wi-Fi + server + room ID over BLE.
8. The ESP32 restarts and starts sending telemetry to `/api/v1/telemetry`.

## Current sensors

- DHT11: temperature + relative humidity
- HC-SR501 PIR: motion/activity state
- analog sound module: relative noise level (not calibrated dB)
- LCD 20x4: local display

## Conference-ready features already represented in the prototype

- multi-building / multi-room topology
- live room state
- environmental score
- sensor health
- device health / RSSI / firmware / last seen
- 24h / 7d / 30d filters
- min / max / average / latest aggregation
- cross-room comparison
- room ranking
- anomaly / trend rules
- active alerts
- AI recommendations
- Gemini chat grounded in actual sensor context
- BLE provisioning and QR-based kit identification
- demo mode for presentation without live hardware

## Security note

Never hard-code Gemini credentials into Flutter or ESP32 code. Keep the key in the backend environment only.
