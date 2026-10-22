#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>

// ESP32-WROOM/DevKit classico: GPIO18 -> resistor 220-330 ohms -> anodo do LED.
// Catodo do LED -> GND. Confira o pinout da sua placa antes de montar.
static const int LED_PIN = 18;
static const unsigned long MAX_LED_ON_MS = 60000;
static const char* DEVICE_NAME = "ESP32_ROLETA";
static const char* SERVICE_UUID = "6f400001-b5a3-f393-e0a9-e50e24dcca9e";
static const char* COMMAND_UUID = "6f400002-b5a3-f393-e0a9-e50e24dcca9e";

bool ledIsOn = false;
unsigned long ledStartedAt = 0;

void setChallengeLed(bool on) {
  ledIsOn = on;
  digitalWrite(LED_PIN, on ? HIGH : LOW);
  if (on) ledStartedAt = millis();
}

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {}
  void onDisconnect(BLEServer* server) override {
    setChallengeLed(false);
    server->startAdvertising();
  }
};

class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    String command = characteristic->getValue().c_str();
    command.trim();
    command.toUpperCase();
    if (command == "START") setChallengeLed(true);
    if (command == "STOP") setChallengeLed(false);
  }
};

void setup() {
  pinMode(LED_PIN, OUTPUT);
  setChallengeLed(false);
  Serial.begin(115200);
  BLEDevice::init(DEVICE_NAME);
  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  BLEService* service = server->createService(SERVICE_UUID);
  BLECharacteristic* characteristic = service->createCharacteristic(
    COMMAND_UUID, BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  characteristic->setCallbacks(new CommandCallbacks());
  service->start();
  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.println("Roleta da Sorte pronta. Conecte pelo app ClubRobot.");
}

void loop() {
  if (ledIsOn && millis() - ledStartedAt >= MAX_LED_ON_MS) {
    setChallengeLed(false);
    Serial.println("LED desligado pelo limite de seguranca.");
  }
  delay(20);
}
