import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static final Guid serviceUuid =
      Guid('6f400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid commandUuid =
      Guid('6f400002-b5a3-f393-e0a9-e50e24dcca9e');

  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandCharacteristic;

  BluetoothDevice? get device => _device;
  bool get isConnected => _device != null && _commandCharacteristic != null;

  Future<String> connectToGuincho() async {
    await FlutterBluePlus.adapterState
        .where((state) => state == BluetoothAdapterState.on)
        .first
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Ligue o Bluetooth do celular.'),
        );

    BluetoothDevice? found;
    StreamSubscription<List<ScanResult>>? subscription;

    try {
      subscription = FlutterBluePlus.onScanResults.listen((results) {
        for (final result in results) {
          final advName = result.advertisementData.advName.toUpperCase();
          final platformName = result.device.platformName.toUpperCase();

          final nameMatches = advName.contains('GUINCHO') ||
              platformName.contains('GUINCHO') ||
              advName.contains('ESP32') ||
              platformName.contains('ESP32');

          final serviceMatches = result.advertisementData.serviceUuids
              .any((uuid) => uuid == serviceUuid);

          if (found == null && (nameMatches || serviceMatches)) {
            found = result.device;
          }
        }
      });

      await FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: const Duration(seconds: 8),
      );

      await FlutterBluePlus.isScanning.where((value) => value == false).first;
    } finally {
      await subscription?.cancel();
      await FlutterBluePlus.stopScan();
    }

    if (found == null) {
      throw Exception(
        'ESP32_GUINCHO não encontrado. Confira se o ESP32 está ligado.',
      );
    }

    final device = found!;
    await device.connect(timeout: const Duration(seconds: 12));

    final services = await device.discoverServices();

    BluetoothCharacteristic? characteristic;

    for (final service in services) {
      if (service.uuid == serviceUuid) {
        for (final c in service.characteristics) {
          if (c.uuid == commandUuid) {
            characteristic = c;
            break;
          }
        }
      }
    }

    if (characteristic == null) {
      await device.disconnect();
      throw Exception(
        'O ESP32 foi encontrado, mas o serviço do guincho não está disponível.',
      );
    }

    _device = device;
    _commandCharacteristic = characteristic;

    return device.platformName.isNotEmpty
        ? device.platformName
        : 'ESP32_GUINCHO';
  }

  Future<void> send(String command) async {
    final characteristic = _commandCharacteristic;
    if (characteristic == null) {
      throw Exception('ESP32 não conectado.');
    }

    await characteristic.write(
      utf8.encode(command),
      withoutResponse: characteristic.properties.writeWithoutResponse,
    );
  }

  Future<void> disconnect() async {
    final d = _device;
    _commandCharacteristic = null;
    _device = null;

    if (d != null) {
      try {
        await d.disconnect();
      } catch (_) {}
    }
  }

  void dispose() {
    disconnect();
  }
}
