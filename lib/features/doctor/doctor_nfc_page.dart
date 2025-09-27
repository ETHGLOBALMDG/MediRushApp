import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../../core/themes.dart';
import '../../services/nfc_service.dart';
import '../auth/onboarding_page.dart';

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
  // Patient's Data
  String _patientNfcData = "No card scanned yet.";
  bool _patientTagDetected = false;
  bool _patientIsScanning = false;

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

  /// Starts the NFC scan session
  void _startPatientNfcSession() async {
    setState(() {
      _patientNfcData = "Scanning NFC card...";
      _patientTagDetected = false;
      _patientIsScanning = true;
    });

    try {
      // Read text records from NFC tag
      List<String> records = await NFCService.readAllRecords();

      setState(() {
        _patientTagDetected = records.isNotEmpty;
        _patientNfcData = records.isEmpty
            ? "No NDEF text found or tag not writable"
            : records.join("\n");
      });
    } catch (e) {
      setState(() {
        _patientTagDetected = false;
        _patientNfcData = "Error reading NFC: $e";
      });
    } finally {
      setState(() {
        _patientIsScanning = false;
      });
    }
  }

  /// Writes data to the NFC tag
  // Assuming WalletAddrService is initialized and available
  final WalletAddrService _walletAddrService = WalletAddrService();

  void _writeNfcData() async {
    setState(() {
      _isWriting = true;
    });

    try {
      // 1. Get the wallet address synchronously (assuming Option 2: init() was called)
      String? walletAddress = await _walletAddrService.getAddress();

      if (walletAddress == null) {
        // Handle the case where no address is stored
        setState(() {
          _nfcData = "Error: No wallet address found.";
        });
        return; // Exit the function
      }

      // 2. Write the retrieved wallet address to NFC
      // Note: Use 'walletAddress' instead of the old 'text' variable
      bool success = await NFCService.writeText(walletAddress);

      setState(() {
        _nfcData = success
            ? "Wallet Address written: $walletAddress"
            : "Failed to write wallet address to NFC";
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

  /// Returns the decoded JSON response body if successful (status code 200),
  /// otherwise throws an exception.
  /// Send a POST request to the backend server when the doctor scans the patient's NFC card
  Future<Map<String, dynamic>> sendPostRequest({
    required String url,
    required String data,
  }) async {
    try {
      // 1. Prepare the request URL
      final uri = Uri.parse(url);

      // 2. Convert the Dart map (JSON data) into a JSON string
      final body = data;

      // 3. Send the POST request
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json', // Essential for sending JSON data
          'Accept': 'application/json', // To request a JSON response
        },
        body: body,
      );

      // 4. Check the status code
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success: Return the decoded response body
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        // Failure: Throw an exception with status code and body
        throw Exception(
          'Failed to post data. Status code: ${response.statusCode}. Body: ${response.body}',
        );
      }
    } on Exception catch (e) {
      // Handle network or parsing errors
      throw Exception('Request failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediRush', style: headingTextStyle),
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
              Text("Update NFC", style: headingTextStyle),
              const SizedBox(height: 8),
              if (!_tagDetected) ...[
                Text(
                  "Tap your NFC card to update your wallet address in the NFC. Ensure compatibility.",
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
                SizedBox(height: 20),

                // Container to write data into NFC
                GestureDetector(
                  onTap: _isWriting ? () {} : () => _writeNfcData(),
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: lightGreenColor, width: 2),
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Text("Tap to Write", style: heading2TextStyle),
                          SizedBox(height: 10),
                          Image.asset("assets/nfcicon.png"),
                          SizedBox(height: 10),
                          Text(
                            "Hold your NFC card near the back of your phone to write your wallet address into it",
                            style: body2TextStyle,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),

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

              const SizedBox(height: 16),
              const Divider(color: Colors.grey, thickness: 0.5),
              const SizedBox(height: 16),

              Text("Fetch Patient's Records", style: headingTextStyle),

              const SizedBox(height: 10),
              Text(
                "Tap the patient's NFC card to show their detailed medical history on your website.",
                style: bodyTextStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Scan NFC Button
              rowButton(
                onPressed: _patientIsScanning ? () {} : _startPatientNfcSession,
                widgets: [
                  _patientIsScanning
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.nfc),
                  const SizedBox(width: 8),
                  Text(
                    _patientIsScanning ? "Scanning..." : "Tap NFC Card",
                    style: buttonTextStyle,
                  ),
                ],
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black,
                borderRadius: 8,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),

              const SizedBox(height: 16),

              // TODO: Remove this section
              Text("Scanned NFC Data", style: heading2TextStyle),
              const SizedBox(height: 8),
              Text(_patientNfcData, style: body2TextStyle),

              const SizedBox(height: 10),
              if (_patientTagDetected)
                rowButton(
                  onPressed: () => sendPostRequest(
                      url: "mybackendurl.com", data: _patientNfcData),
                  widgets: [
                    const Icon(Icons.arrow_upward_rounded),
                    const SizedBox(width: 8),
                    Text(
                      "Send Patient Details to Website",
                      style: buttonTextStyle,
                    ),
                  ],
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black,
                  borderRadius: 8,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
