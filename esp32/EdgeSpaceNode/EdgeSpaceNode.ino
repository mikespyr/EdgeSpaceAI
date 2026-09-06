#include <WiFi.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <DHT.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// EdgeSpace AI reference firmware for ESP32-C3.
// Based on the same sensor wiring as the user's existing IoT kit.
// Wi-Fi credentials are provisioned over BLE and stored in NVS; never hard-code them.

#define DHTPIN 2
#define DHTTYPE DHT11
#define PIR_PIN 4
#define PIR_LED 5
#define NOISE_DO_PIN 18
#define NOISE_AO_PIN 0
#define STATUS_LED 10
#define I2C_SDA 8
#define I2C_SCL 9

static const char* SERVICE_UUID   = "8f9d0001-56aa-4d70-b44a-2e64a087a001";
static const char* SSID_UUID      = "8f9d0002-56aa-4d70-b44a-2e64a087a001";
static const char* PASSWORD_UUID  = "8f9d0003-56aa-4d70-b44a-2e64a087a001";
static const char* SERVER_UUID    = "8f9d0004-56aa-4d70-b44a-2e64a087a001";
static const char* ROOM_UUID      = "8f9d0005-56aa-4d70-b44a-2e64a087a001";
static const char* DEVICE_UUID    = "8f9d0006-56aa-4d70-b44a-2e64a087a001";
static const char* APPLY_UUID     = "8f9d0007-56aa-4d70-b44a-2e64a087a001";
static const char* STATUS_UUID    = "8f9d0008-56aa-4d70-b44a-2e64a087a001";

DHT dht(DHTPIN, DHTTYPE);
LiquidCrystal_I2C lcd(0x27, 20, 4);
Preferences prefs;

String cfgSsid;
String cfgPassword;
String cfgServer;
String cfgRoom;
String cfgDevice;
String pendingSsid;
String pendingPassword;
String pendingServer;
String pendingRoom;
String pendingDevice;
String bleStatus = "READY";

BLECharacteristic* statusCharacteristic = nullptr;
unsigned long lastTelemetry = 0;
unsigned long lastLcd = 0;
bool motionDetected = false;
bool noiseDetected = false;
int noiseLevel = 0;

String chipId() {
  uint64_t id = ESP.getEfuseMac();
  char buf[13];
  snprintf(buf, sizeof(buf), "%04X%08X", (uint16_t)(id >> 32), (uint32_t)id);
  return String(buf);
}

void loadConfig() {
  prefs.begin("edgespace", true);
  cfgSsid = prefs.getString("ssid", "");
  cfgPassword = prefs.getString("pass", "");
  cfgServer = prefs.getString("server", "");
  cfgRoom = prefs.getString("room", "");
  cfgDevice = prefs.getString("device", "");
  prefs.end();
  if (cfgDevice.isEmpty()) cfgDevice = "esp32c3-" + chipId();
}

void saveConfig() {
  prefs.begin("edgespace", false);
  prefs.putString("ssid", pendingSsid);
  prefs.putString("pass", pendingPassword);
  prefs.putString("server", pendingServer);
  prefs.putString("room", pendingRoom);
  prefs.putString("device", pendingDevice.isEmpty() ? cfgDevice : pendingDevice);
  prefs.end();
}

class FieldCallback : public BLECharacteristicCallbacks {
 public:
  explicit FieldCallback(String* target) : target_(target) {}
  void onWrite(BLECharacteristic* c) override {
    std::string raw = c->getValue();
    *target_ = String(raw.c_str());
  }
 private:
  String* target_;
};

class ApplyCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    std::string raw = c->getValue();
    if (String(raw.c_str()) != "SAVE") return;
    if (pendingSsid.isEmpty() || pendingServer.isEmpty() || pendingRoom.isEmpty()) {
      bleStatus = "MISSING_FIELDS";
      if (statusCharacteristic) statusCharacteristic->setValue(bleStatus.c_str());
      return;
    }
    bleStatus = "SAVED_RESTARTING";
    if (statusCharacteristic) statusCharacteristic->setValue(bleStatus.c_str());
    saveConfig();
    delay(500);
    ESP.restart();
  }
};

void startBleProvisioning() {
  BLEDevice::init(("EdgeSpace-" + chipId().substring(6)).c_str());
  BLEServer* server = BLEDevice::createServer();
  BLEService* service = server->createService(SERVICE_UUID);

  auto makeWrite = [&](const char* uuid, String* target) {
    BLECharacteristic* c = service->createCharacteristic(uuid, BLECharacteristic::PROPERTY_WRITE);
    c->setCallbacks(new FieldCallback(target));
  };
  makeWrite(SSID_UUID, &pendingSsid);
  makeWrite(PASSWORD_UUID, &pendingPassword);
  makeWrite(SERVER_UUID, &pendingServer);
  makeWrite(ROOM_UUID, &pendingRoom);
  makeWrite(DEVICE_UUID, &pendingDevice);

  BLECharacteristic* apply = service->createCharacteristic(APPLY_UUID, BLECharacteristic::PROPERTY_WRITE);
  apply->setCallbacks(new ApplyCallback());
  statusCharacteristic = service->createCharacteristic(STATUS_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  statusCharacteristic->addDescriptor(new BLE2902());
  statusCharacteristic->setValue(bleStatus.c_str());

  service->start();
  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  BLEDevice::startAdvertising();
}

void connectWiFi() {
  if (cfgSsid.isEmpty()) return;
  WiFi.mode(WIFI_STA);
  WiFi.begin(cfgSsid.c_str(), cfgPassword.c_str());
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) {
    delay(250);
  }
}

void postTelemetry(float temperature, float humidity) {
  if (WiFi.status() != WL_CONNECTED || cfgServer.isEmpty() || cfgRoom.isEmpty()) return;
  HTTPClient http;
  String endpoint = cfgServer + "/api/v1/telemetry";
  http.begin(endpoint);
  http.addHeader("Content-Type", "application/json");

  String body = "{";
  body += "\"device_id\":\"" + cfgDevice + "\",";
  body += "\"room_id\":\"" + cfgRoom + "\",";
  if (!isnan(temperature)) body += "\"temperature\":" + String(temperature, 1) + ",";
  if (!isnan(humidity)) body += "\"humidity\":" + String(humidity, 1) + ",";
  body += "\"motion\":" + String(motionDetected ? "true" : "false") + ",";
  body += "\"noise\":" + String(noiseLevel) + ",";
  body += "\"rssi\":" + String(WiFi.RSSI());
  body += "}";

  int code = http.POST(body);
  digitalWrite(STATUS_LED, code >= 200 && code < 300 ? HIGH : LOW);
  http.end();
}

void updateLcd(float t, float h) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(WiFi.status() == WL_CONNECTED ? "EdgeSpace ONLINE" : "EdgeSpace OFFLINE");
  lcd.setCursor(0, 1);
  if (!isnan(t) && !isnan(h)) {
    lcd.print("T:"); lcd.print(t, 1); lcd.print("C H:"); lcd.print(h, 0); lcd.print("%");
  } else {
    lcd.print("DHT ERROR");
  }
  lcd.setCursor(0, 2);
  lcd.print("PIR:"); lcd.print(motionDetected ? "YES" : "NO");
  lcd.print(" N:"); lcd.print(noiseLevel);
  lcd.setCursor(0, 3);
  lcd.print(cfgRoom.length() > 19 ? cfgRoom.substring(0, 19) : cfgRoom);
}

void setup() {
  Serial.begin(115200);
  pinMode(STATUS_LED, OUTPUT);
  pinMode(PIR_PIN, INPUT);
  pinMode(PIR_LED, OUTPUT);
  pinMode(NOISE_DO_PIN, INPUT);

  dht.begin();
  Wire.begin(I2C_SDA, I2C_SCL);
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.print("EdgeSpace boot...");

  loadConfig();
  pendingSsid = cfgSsid;
  pendingPassword = cfgPassword;
  pendingServer = cfgServer;
  pendingRoom = cfgRoom;
  pendingDevice = cfgDevice;

  // Always advertise so the app can reconfigure/reassign the kit nearby.
  startBleProvisioning();
  connectWiFi();
}

void loop() {
  motionDetected = digitalRead(PIR_PIN) == HIGH;
  digitalWrite(PIR_LED, motionDetected ? HIGH : LOW);
  noiseLevel = analogRead(NOISE_AO_PIN);
  noiseDetected = noiseLevel > 400;

  float t = dht.readTemperature();
  float h = dht.readHumidity();

  if (millis() - lastLcd >= 1000) {
    lastLcd = millis();
    updateLcd(t, h);
  }

  if (millis() - lastTelemetry >= 5000) {
    lastTelemetry = millis();
    if (WiFi.status() != WL_CONNECTED && !cfgSsid.isEmpty()) connectWiFi();
    postTelemetry(t, h);
  }
  delay(30);
}
