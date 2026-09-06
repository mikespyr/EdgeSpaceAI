import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService extends ChangeNotifier {
  bool _isScanning = false;
  bool _hasPermission = false;

  String? _errorMessage;

  final List<ScanResult> _scanResults = [];

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  bool get isScanning => _isScanning;

  bool get hasPermission => _hasPermission;

  String? get errorMessage => _errorMessage;

  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);

  // ============================================================
  // Permissions
  // ============================================================

  Future<bool> requestPermissions() async {
    try {
      if (!Platform.isAndroid) {
        _hasPermission = true;
        notifyListeners();
        return true;
      }

      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      final scanGranted =
          statuses[Permission.bluetoothScan]?.isGranted ?? false;

      final connectGranted =
          statuses[Permission.bluetoothConnect]?.isGranted ?? false;

      _hasPermission = scanGranted && connectGranted;

      if (!_hasPermission) {
        _errorMessage =
            'Bluetooth permission is required to discover nearby devices.';
      } else {
        _errorMessage = null;
      }

      notifyListeners();

      return _hasPermission;
    } catch (e) {
      _errorMessage = 'Permission error: $e';

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // Scan
  // ============================================================

  Future<void> startScan() async {
    try {
      _errorMessage = null;

      final permissionGranted = await requestPermissions();

      if (!permissionGranted) {
        return;
      }

      final supported = await FlutterBluePlus.isSupported;

      if (!supported) {
        _errorMessage = 'Bluetooth is not supported on this device.';
        notifyListeners();
        return;
      }

      _scanResults.clear();

      await _scanSubscription?.cancel();

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _scanResults
          ..clear()
          ..addAll(results);

        notifyListeners();
      });

      _isScanning = true;

      notifyListeners();

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );

      await Future.delayed(
        const Duration(seconds: 10),
      );

      _isScanning = false;

      notifyListeners();
    } catch (e) {
      _isScanning = false;

      _errorMessage = 'Bluetooth scan failed: $e';

      notifyListeners();
    }
  }

  // ============================================================
  // Stop scan
  // ============================================================

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();

      _isScanning = false;

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Could not stop Bluetooth scan: $e';

      notifyListeners();
    }
  }

  // ============================================================
  // Clear scan results
  // ============================================================

  void clearResults() {
    _scanResults.clear();

    notifyListeners();
  }

  // ============================================================
  // Dispose
  // ============================================================

  @override
  void dispose() {
    _scanSubscription?.cancel();

    super.dispose();
  }
}
