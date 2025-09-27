import 'package:app_frontend/core/themes.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanner extends StatefulWidget {
  const QrScanner({super.key});

  @override
  State<QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<QrScanner> {
  // We use a controller to manage the camera state.
  final MobileScannerController cameraController = MobileScannerController();
  bool _isScanned = false; // Prevents multiple scans from the same QR code

  @override
  void dispose() {
    // Make sure to dispose the controller when the state is removed
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scan QR Code',
          style: heading2TextStyle,
        ),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          // MobileScanner widget to display the camera feed and handle scanning.
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              // Ensure we only process the first scan.
              if (barcodes.isNotEmpty && !_isScanned) {
                final String code = barcodes.first.rawValue ?? "No data found";
                _isScanned = true;

                // Return the scanned data to the previous screen.
                Navigator.pop(context, code);
              }
            },
          ),
          // A semi-transparent overlay to create a scanning window effect.
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const SizedBox.shrink(), // Placeholder for the scan area
            ),
          ),
          // Optional: Add a text overlay to guide the user.
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Point the camera at a QR code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
