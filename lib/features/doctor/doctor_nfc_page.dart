import 'package:flutter/material.dart';

import '../../core/themes.dart';
import '../../services/nfc_service.dart';

class DoctorNfcPage extends StatefulWidget {
  const DoctorNfcPage({super.key});

  @override
  State<DoctorNfcPage> createState() => _DoctorNfcPageState();
}

class _DoctorNfcPageState extends State<DoctorNfcPage> {
  String _nfcData = "No card scanned yet.";
  bool _tagDetected = false;
  bool _isScanning = false;
  bool _isWriting = false;

  /// Starts the NFC scan session
  void _startNfcSession() async {
    setState(() {
      _nfcData = "Scanning NFC card...";
      _tagDetected = false;
      _isScanning = true;
    });

    try {
      // Read text records from NFC tag
      List<String> records = await NFCService.readAllRecords();

      setState(() {
        _tagDetected = records.isNotEmpty;
        _nfcData = records.isEmpty
            ? "No NDEF text found or tag not writable"
            : records.join("\n");
      });
    } catch (e) {
      setState(() {
        _tagDetected = false;
        _nfcData = "Error reading NFC: $e";
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  /// Writes data to the NFC tag
  void _writeNfcData(String text) async {
    setState(() {
      _isWriting = true;
    });

    try {
      bool success = await NFCService.writeText(text);

      setState(() {
        _nfcData = success ? "Text written: $text" : "Failed to write to NFC";
      });
    } catch (e) {
      setState(() {
        _nfcData = "Error writing NFC: $e";
      });
    } finally {
      setState(() {
        _isWriting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VeriMed', style: headingTextStyle),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              //
              // NFC SECTION
              //
              Text("NFC Card Management", style: headingTextStyle),
              const SizedBox(height: 8),
              if (!_tagDetected) ...[
                Text(
                  "Tap your NFC card to update or fetch your medical license. Ensure compatibility.",
                  style: bodyTextStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
              ],

              const SizedBox(height: 10),

              // Scan NFC Button
              rowButton(
                onPressed: _isScanning ? () {} : _startNfcSession,
                widgets: [
                  _isScanning
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.nfc),
                  const SizedBox(width: 8),
                  Text(
                    _isScanning ? "Scanning..." : "Tap NFC Card",
                    style: buttonTextStyle,
                  ),
                ],
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black,
                borderRadius: 8,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),

              const SizedBox(height: 12),

              // Show buttons if NFC tag detected
              if (_tagDetected) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Card Status - Connected
                    Container(
                      decoration: BoxDecoration(
                        color: lightGreenColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Image.asset(
                            "assets/wifi.png",
                            width: 40,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Card Status",
                                style: body2DarkTextStyle,
                              ),
                              Text(
                                "Connected",
                                style: body2TextStyle,
                              ),
                            ],
                          )
                        ],
                      ),
                    ),

                    // Data Synced - Synced
                    Container(
                      decoration: BoxDecoration(
                        color: lightGreenColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Image.asset(
                            "assets/sync.png",
                            width: 40,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Data Synced",
                                style: body2DarkTextStyle,
                              ),
                              Text(
                                "Synced",
                                style: body2TextStyle,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                // Container to write data into NFC
                GestureDetector(
                  onTap: _isWriting ? () {} : () => _writeNfcData(""),
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: lightGreenColor, width: 2),
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Text("Tap Card to Write / Update",
                              style: heading2TextStyle),
                          SizedBox(height: 10),
                          Image.asset("assets/nfcicon.png"),
                          SizedBox(height: 10),
                          Text(
                            "Hold your NFC card near the back of your phone to write or update data",
                            style: body2TextStyle,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Data Written and Read
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Data Written
                    Container(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Image.asset(
                            "assets/datawr.png",
                            width: 40,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Data Written",
                                style: body2DarkTextStyle,
                              ),
                              Text(
                                "Placeholder",
                                style: body2TextStyle,
                              ),
                            ],
                          )
                        ],
                      ),
                    ),

                    // Data Read
                    Container(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Image.asset(
                            "assets/datard.png",
                            width: 40,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Data Read",
                                style: body2DarkTextStyle,
                              ),
                              Text(
                                "Placeholder",
                                style: body2TextStyle,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Cancel NFC
                rowButton(
                  onPressed: () {
                    setState(() {
                      _tagDetected = false;
                      _nfcData = "No card scanned yet.";
                    });
                  },
                  widgets: const [
                    Icon(Icons.cancel, color: Colors.black),
                    SizedBox(width: 6),
                    Text(
                      "Cancel",
                      style: buttonTextStyle,
                    ),
                  ],
                  backgroundColor: lightColor,
                  foregroundColor: Colors.white,
                  borderRadius: 8,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ],

              const SizedBox(height: 16),

              // TODO: Remove this section
              Text("Scanned NFC Data", style: heading2TextStyle),
              const SizedBox(height: 8),
              Text(_nfcData, style: body2TextStyle),
            ],
          ),
        ),
      ),
    );
  }
}
