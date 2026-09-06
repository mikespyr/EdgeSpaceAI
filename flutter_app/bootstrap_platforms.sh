#!/usr/bin/env sh
set -eu
flutter create --platforms=android,ios .
flutter pub get
echo "Platform folders created. Apply the BLE/camera permissions from PLATFORM_PERMISSIONS.md."
