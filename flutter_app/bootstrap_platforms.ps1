$ErrorActionPreference = "Stop"
flutter create --platforms=android,ios .
flutter pub get
Write-Host "Platform folders created. Now apply the Android/iOS BLE & camera permissions from PLATFORM_PERMISSIONS.md."
