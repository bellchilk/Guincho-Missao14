#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <ESP32Servo.h>

#define SERVICE_UUID "6f400001-b5a3-f393-e0a9-e50e24dcca9e"
#define COMMAND_UUID "6f400002-b5a3-f393-e0a9-e50e24dcca9e"

Servo servoGuincho;
Servo servoDirecao;

// Ajuste de acordo com a montagem física.
const int PINO_GUINCHO = 18;
const int PINO_DIRECAO = 19;

// Servo contínuo: normalmente 90 = parado.
// Ajuste os valores conforme o servo real.
const int GUINCHO_PARADO = 90;
const int GUINCHO_SUBIR = 120;
const int GUINCHO_DESCER = 60;

// Servo comum da direção.
const int DIRECAO_CENTRO = 90;
const int DIRECAO_ESQUERDA = 45;
const int DIRECAO_DIREITA = 135;

void parar() {
  servoGuincho.write(GUINCHO_PARADO);
  Serial.println("PARAR");
}

void subir() {
  servoGuincho.write(GUINCHO_SUBIR);
  Serial.println("SUBIR");
}

void descer() {
  servoGuincho.write(GUINCHO_DESCER);
  Serial.println("DESCER");
}

void esquerda() {
  servoDirecao.write(DIRECAO_ESQUERDA);
  Serial.println("ESQUERDA");
}

void direita() {
  servoDirecao.write(DIRECAO_DIREITA);
  Serial.println("DIREITA");
}

class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) override {
    String value = characteristic->getValue();

    if (value.length() == 0) return;

    char comando = value.charAt(0);

    switch (comando) {
      case 'S':
        subir();
        break;

      case 'D':
        descer();
        break;

      case 'P':
        parar();
        break;

      case 'E':
        esquerda();
        break;

      case 'R':
        direita();
        break;

      default:
        parar();
        break;
    }
  }
};

void setup() {
  Serial.begin(115200);

  servoGuincho.attach(PINO_GUINCHO);
  servoDirecao.attach(PINO_DIRECAO);

  parar();
  servoDirecao.write(DIRECAO_CENTRO);

  BLEDevice::init("ESP32_GUINCHO");

  BLEServer *server = BLEDevice::createServer();
  BLEService *service = server->createService(SERVICE_UUID);

  BLECharacteristic *commandCharacteristic =
      service->createCharacteristic(
        COMMAND_UUID,
        BLECharacteristic::PROPERTY_WRITE |
        BLECharacteristic::PROPERTY_WRITE_NR
      );

  commandCharacteristic->setCallbacks(new CommandCallbacks());

  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);

  BLEDevice::startAdvertising();

  Serial.println("ESP32_GUINCHO pronto.");
}

void loop() {
  delay(50);
}
