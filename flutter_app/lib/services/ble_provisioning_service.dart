import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ProvisionCandidate {
  ProvisionCandidate({
    required this.device,
    required this.name,
    required this.rssi,
  });

  final BluetoothDevice device;
  final String name;
  final int rssi;
}

class BleProvisioningService {
  static final Guid serviceUuid = Guid('8f9d0001-56aa-4d70-b44a-2e64a087a001');
  static final Guid ssidUuid = Guid('8f9d0002-56aa-4d70-b44a-2e64a087a001');
  static final Guid passwordUuid = Guid('8f9d0003-56aa-4d70-b44a-2e64a087a001');
  static final Guid serverUuid = Guid('8f9d0004-56aa-4d70-b44a-2e64a087a001');
  static final Guid roomUuid = Guid('8f9d0005-56aa-4d70-b44a-2e64a087a001');
  static final Guid deviceIdUuid = Guid('8f9d0006-56aa-4d70-b44a-2e64a087a001');
  static final Guid applyUuid = Guid('8f9d0007-56aa-4d70-b44a-2e64a087a001');
  static final Guid statusUuid = Guid('8f9d0008-56aa-4d70-b44a-2e64a087a001');

  Future<void> _ensureReady() async {
    final supported = await FlutterBluePlus.isSupported;

    if (!supported) {
      throw Exception('Bluetooth is not supported on this device.');
    }

    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      final scanGranted =
          statuses[Permission.bluetoothScan]?.isGranted ?? false;
      final connectGranted =
          statuses[Permission.bluetoothConnect]?.isGranted ?? false;

      if (!scanGranted || !connectGranted) {
        throw Exception(
          'Bluetooth permission is required to discover and configure ESP32-C3 devices.',
        );
      }
    }

    final adapterState = await FlutterBluePlus.adapterState.first;

    if (adapterState != BluetoothAdapterState.on) {
      throw Exception('Bluetooth is turned off. Turn it on and try again.');
    }
  }

  Future<List<ProvisionCandidate>> scan({
    Duration timeout = const Duration(seconds: 7),
  }) async {
    await _ensureReady();

    final found = <String, ProvisionCandidate>{};

    Future<void> runPass({
      required Duration passTimeout,
      required bool strictServiceFilter,
    }) async {
      final subscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          for (final result in results) {
            final advertisedName = result.advertisementData.advName.trim();
            final lowerName = advertisedName.toLowerCase();
            final advertisesService = result.advertisementData.serviceUuids
                .any((uuid) => uuid == serviceUuid);

            final looksLikeEsp = lowerName.contains('edgespace') ||
                lowerName.contains('esp32') ||
                lowerName.startsWith('esp-') ||
                lowerName == 'esp';

            if (!strictServiceFilter && !advertisesService && !looksLikeEsp) {
              continue;
            }

            final name = advertisedName.isEmpty
                ? 'EdgeSpace Kit'
                : advertisedName;

            found[result.device.remoteId.str] = ProvisionCandidate(
              device: result.device,
              name: name,
              rssi: result.rssi,
            );
          }
        },
      );

      try {
        await FlutterBluePlus.stopScan();

        if (strictServiceFilter) {
          await FlutterBluePlus.startScan(
            withServices: [serviceUuid],
            timeout: passTimeout,
          );
        } else {
          await FlutterBluePlus.startScan(
            timeout: passTimeout,
          );
        }

        await Future<void>.delayed(passTimeout);
      } finally {
        await FlutterBluePlus.stopScan();
        await subscription.cancel();
      }
    }

    final firstPass = timeout.inMilliseconds >= 6000
        ? const Duration(seconds: 4)
        : timeout;

    await runPass(
      passTimeout: firstPass,
      strictServiceFilter: true,
    );

    // Some ESP32 firmware exposes the provisioning service in GATT but does
    // not include the UUID in the advertising packet. In that case a strict
    // service-filtered Android scan returns nothing, so fall back to a short
    // nearby-device scan and keep only ESP/EdgeSpace-looking devices.
    if (found.isEmpty) {
      await runPass(
        passTimeout: const Duration(seconds: 4),
        strictServiceFilter: false,
      );
    }

    return found.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  Future<String> provision({
    required BluetoothDevice device,
    required String ssid,
    required String password,
    required String serverUrl,
    required String deviceId,
    required String roomId,
  }) async {
    await _ensureReady();

    bool connectedByUs = false;

    try {
      try {
        await device.connect(
          timeout: const Duration(seconds: 12),
          autoConnect: false,
        );
        connectedByUs = true;
      } catch (e) {
        final message = e.toString().toLowerCase();
        if (!message.contains('already connected')) {
          rethrow;
        }
      }

      try {
        await device.requestMtu(247);
      } catch (_) {
        // Some devices/platforms do not allow changing the MTU.
      }

      final services = await device.discoverServices();

      BluetoothService? provisioningService;
      for (final service in services) {
        if (service.uuid == serviceUuid) {
          provisioningService = service;
          break;
        }
      }

      if (provisioningService == null) {
        throw Exception(
          'EdgeSpace provisioning service was not found on this device.',
        );
      }

      BluetoothCharacteristic characteristic(Guid uuid) {
        for (final item in provisioningService!.characteristics) {
          if (item.uuid == uuid) {
            return item;
          }
        }

        throw Exception(
          'Required EdgeSpace BLE characteristic $uuid was not found.',
        );
      }

      await characteristic(ssidUuid).write(
        utf8.encode(ssid),
        withoutResponse: false,
      );

      await characteristic(passwordUuid).write(
        utf8.encode(password),
        withoutResponse: false,
      );

      await characteristic(serverUuid).write(
        utf8.encode(serverUrl),
        withoutResponse: false,
      );

      await characteristic(roomUuid).write(
        utf8.encode(roomId),
        withoutResponse: false,
      );

      await characteristic(deviceIdUuid).write(
        utf8.encode(deviceId),
        withoutResponse: false,
      );

      await characteristic(applyUuid).write(
        utf8.encode('SAVE'),
        withoutResponse: false,
      );

      await Future<void>.delayed(
        const Duration(milliseconds: 700),
      );

      final bytes = await characteristic(statusUuid).read();
      final status = utf8.decode(bytes, allowMalformed: true).trim();

      return status.isEmpty ? 'Configuration saved.' : status;
    } finally {
      if (connectedByUs) {
        try {
          await device.disconnect();
        } catch (_) {
          // The ESP32 may reboot immediately after applying Wi-Fi settings.
        }
      }
    }
  }
}
