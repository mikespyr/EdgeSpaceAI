# Android / iOS permissions

After `flutter create .`, add the following permissions.

## Android: `android/app/src/main/AndroidManifest.xml`
Inside `<manifest ...>` and before `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.CAMERA" />
```

For development with a local HTTP backend, add this to `<application>`:

```xml
android:usesCleartextTraffic="true"
```

Use HTTPS in production.

## iOS: `ios/Runner/Info.plist`
Add inside `<dict>`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>EdgeSpace AI uses Bluetooth to discover and configure nearby ESP32-C3 kits.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>EdgeSpace AI uses Bluetooth to provision nearby IoT kits.</string>
<key>NSCameraUsageDescription</key>
<string>EdgeSpace AI uses the camera to scan device QR labels.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>EdgeSpace AI connects to the local EdgeSpace backend and IoT devices.</string>
```
