import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/app_theme.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  var handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Kit QR')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (handled || capture.barcodes.isEmpty) return;
              final value = capture.barcodes.first.rawValue;
              if (value == null || value.isEmpty) return;
              handled = true;
              Navigator.pop(context, value);
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: EdgeColors.cyan, width: 2)),
              ),
            ),
          ),
          const Positioned(left: 24, right: 24, bottom: 54, child: Text('Place the QR label of the ESP32-C3 kit inside the frame.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
