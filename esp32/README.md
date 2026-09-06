# EdgeSpace AI - ESP32-C3 reference firmware

This firmware matches the current prototype kit:
- ESP32-C3 WROOM
- DHT11 on GPIO2
- HC-SR501 PIR on GPIO4
- PIR LED on GPIO5
- analog noise sensor on ADC0 / GPIO0, digital output on GPIO18
- status LED on GPIO10
- LCD 20x4 I2C on SDA GPIO8 / SCL GPIO9, address 0x27

## Provisioning
The Flutter app writes Wi-Fi SSID, password, backend URL, room ID and device ID over BLE. The values are stored in ESP32 NVS (`Preferences`) and the kit restarts.

## Telemetry
Every 5 seconds the kit POSTs JSON to:
`POST /api/v1/telemetry`

The analog noise value is a relative sensor level (0-4095), **not calibrated dB**.

## Important
Do not put the Gemini API key on the ESP32. Gemini requests belong on the backend only.
