import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static final Guid serviceUuid = Guid('6f400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid commandUuid = Guid('6f400002-b5a3-f393-e0a9-e50e24dcca9e');
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  bool get isConnected => _device != null && _characteristic != null;

  Future<String> connect() async {
    await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first.timeout(
      const Duration(seconds: 10), onTimeout: () => throw Exception('Ative o Bluetooth do celular.'));
    BluetoothDevice? found;
    StreamSubscription<List<ScanResult>>? sub;
    try {
      sub = FlutterBluePlus.onScanResults.listen((results) {
        for (final result in results) {
          final name = '${result.advertisementData.advName} ${result.device.platformName}'.toUpperCase();
          final serviceMatch = result.advertisementData.serviceUuids.any((u) => u == serviceUuid);
          if (found == null && (name.contains('ROLETA') || name.contains('ESP32') || serviceMatch)) found = result.device;
        }
      });
      await FlutterBluePlus.startScan(withServices: [serviceUuid], timeout: const Duration(seconds: 8));
      await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;
    } finally {
      await sub?.cancel();
      await FlutterBluePlus.stopScan();
    }
    if (found == null) throw Exception('ESP32 da roleta não encontrado. Confira se está ligado.');
    final device = found!;
    await device.connect(timeout: const Duration(seconds: 12));
    final services = await device.discoverServices();
    BluetoothCharacteristic? characteristic;
    for (final service in services) {
      if (service.uuid == serviceUuid) {
        for (final item in service.characteristics) {
          if (item.uuid == commandUuid) characteristic = item;
        }
      }
    }
    if (characteristic == null) {
      await device.disconnect();
      throw Exception('O ESP32 não oferece o serviço BLE esperado.');
    }
    _device = device;
    _characteristic = characteristic;
    return device.platformName.isNotEmpty ? device.platformName : 'ESP32_ROLETA';
  }

  Future<void> send(String command) async {
    final characteristic = _characteristic;
    if (characteristic == null) throw Exception('ESP32 não conectado.');
    await characteristic.write(utf8.encode(command),
      withoutResponse: characteristic.properties.writeWithoutResponse);
  }

  Future<void> disconnect() async {
    final device = _device;
    _characteristic = null;
    _device = null;
    if (device != null) {
      try { await device.disconnect(); } catch (_) {}
    }
  }

  Future<void> dispose() => disconnect();
}
