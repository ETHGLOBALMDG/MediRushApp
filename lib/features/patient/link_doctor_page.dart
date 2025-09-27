import 'package:app_frontend/core/utils.dart';
import 'package:app_frontend/features/doctor/verification_page.dart';
import 'package:app_frontend/features/patient/transactions_page.dart';
import 'package:flutter/material.dart';
import '../../services/nfc_service.dart';
import '../../core/themes.dart';
import 'qr_scanner.dart';

class LinkDoctorPage extends StatefulWidget {
  const LinkDoctorPage({super.key});

  @override
  State<LinkDoctorPage> createState() => _LinkDoctorPageState();
}

class _LinkDoctorPageState extends State<LinkDoctorPage> {
  String _nfcData = "No card scanned yet.";
  bool _showTxnBtn = false;
  String? _qrData = "No QR code scanned yet.";
  bool _tagDetected = false;
  bool _isScanning = false;
  bool _isWriting = false;

  // Doctor's
  String _docNfcData = "No card scanned yet.";
  bool _docTagDetected = false;
  bool _docIsScanning = false;

  // Dates for last read and write
  final SyncDateService _syncDateService = SyncDateService();
  String lastRead = "Not found";
  String lastWrite = "Not found";

  @override
  void initState() {
    super.initState();
    // Call the asynchronous fetch function
    _fetchSyncDates();
  }

  // Function to fetch the sync dates from local storage
  void _fetchSyncDates() async {
    // 1. Fetch dates from SharedPreferences
    String? readDate = await _syncDateService.getLastReadDate();
    String? writeDate = await _syncDateService.getLastWriteDate();

    // 2. Update the state with the fetched values
    setState(() {
      // If a date is found (not null), use it; otherwise, keep "Not found"
      lastRead = readDate ?? "Not found";
      lastWrite = writeDate ?? "Not found";
    });
  }

  // QR Scanner Methods
  void _openQRScanner() async {
    try {
      // Navigate to QR scanner and wait for result
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const QrScanner(),
        ),
      );

      // Handle the scanned QR code data
      if (result != null) {
        setState(() {
          _qrData = result;
          _showTxnBtn = true;
        });

        // Show a success dialog or snackbar
        // _showQRResultDialog(result);
      } else {
        setState(() {
          _qrData = "QR scan was cancelled";
          _showTxnBtn = false;
        });
      }
    } catch (e) {
      setState(() {
        _qrData = "Error scanning QR code: $e";
        _showTxnBtn = false;
      });
    }
  }

  /// Starts the NFC scan session
  void _startNfcSession() async {
    setState(() {
      _nfcData = "Scanning NFC card...";
      _tagDetected = false;
      _isScanning = true;
    });

    try {
      // Read text records from NFC tag
      // For the patient, this will be his wallet address and private key for the Walrus blob
      // Needs to be stripped of http:// and .com and also Uri.decoded before it is an actual JSON as a string
      List<String> records = await NFCService.readAllRecords();

      _tagDetected = records.isNotEmpty;
      if (_tagDetected) {
        _syncDateService.setLastReadDate(getFormattedDateString());
      }

      setState(() {
        _nfcData = records.isEmpty
            ? "No NDEF text found or tag not writable"
            : decodeJsonFromUrl(records.join("\n"));

        if (_tagDetected) {
          lastRead = getFormattedDateString();
        }
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

  void _startDocNfcSession() async {
    setState(() {
      _docNfcData = "Scanning NFC card...";
      _docTagDetected = false;
      _docIsScanning = true;
    });

    try {
      // Read text records from NFC tag
      List<String> records = await NFCService.readAllRecords();

      setState(() {
        _docTagDetected = records.isNotEmpty;
        _docNfcData = records.isEmpty
            ? "No NDEF text found or tag not writable"
            : decodeJsonFromUrl(records.join("\n"));
      });
    } catch (e) {
      setState(() {
        _docTagDetected = false;
        _docNfcData = "Error reading NFC: $e";
      });
    } finally {
      setState(() {
        _docIsScanning = false;
      });
    }
  }

  /// Writes data to the NFC tag
  void _writeNfcData(String text) async {
    setState(() {
      _isWriting = true;
    });

    try {
      String encodedData = Uri.encodeComponent(text);
      String nfcUrl = makeUrl(encodedData);

      bool success = await NFCService.writeText(nfcUrl);
      if (success) {
        _syncDateService.setLastWriteDate(getFormattedDateString());
      }
      setState(() {
        _nfcData = success ? text : "Failed to write to NFC";

        if (success) {
          lastWrite = getFormattedDateString();
        }
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

  // New navigation function triggered by the dynamic button
  void _navigateToTransactionsPage() {
    if (_qrData == null) return;

    final String recordData = _qrData!;

    // Reset state immediately after consumption
    setState(() {
      _qrData = null;
      // _status = "Medical records flow started.";
    });

    // Navigate to the next page, passing the scanned data.
    Navigator.push(
      context,
      MaterialPageRoute(
        // Assuming MedicalRecordsPage is your target page
        builder: (_) => TransactionsPage(recordData: recordData),
      ),
    );
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
              // QR CODE
              // QR Scanner Section
              Text(
                'Link with Doctor',
                style: headingTextStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Scan the QR code on your doctor\'s screen to securely link your account.',
                style: bodyTextStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Tappable QR Scanner Image
              GestureDetector(
                onTap: _openQRScanner,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade100, width: 2),
                    color: lightGreenColor,
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/qrscanner.png',
                        height: 150,
                        width: 150,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to Scan QR Code',
                        style: TextStyle(
                          fontFamily: "Poppins",
                          color: Colors.green.shade300,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // QR Status Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  _qrData!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 12),
              if (_showTxnBtn)
                rowButton(
                  onPressed: _navigateToTransactionsPage,
                  widgets: [
                    Text(
                      "Update Medical History",
                      style: buttonTextStyle,
                    ),
                  ],
                  backgroundColor: lightGreenColor,
                  foregroundColor: Colors.black,
                  borderRadius: 8,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              const SizedBox(height: 12),
              const Divider(color: Colors.grey, thickness: 0.5),
              const SizedBox(height: 12),
              //
              // NFC SECTION
              //
              Text("NFC Card Management", style: headingTextStyle),
              const SizedBox(height: 8),
              if (!_tagDetected) ...[
                Text(
                  "Tap your NFC card to store or update your medical data. Ensure compatibility.",
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
                  onTap: _isWriting
                      ? () {}
                      : () => _writeNfcData("http://somerandomdata.com"),
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

                // Data Wrriten and Read
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
                                lastWrite,
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
                                lastRead,
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

              const SizedBox(height: 12),
              const Divider(color: Colors.grey, thickness: 0.5),
              const SizedBox(height: 12),

              // VERIFY DOCTOR'S LICENSE
              Text("Verify Doctor's License", style: headingTextStyle),

              const SizedBox(height: 8),

              // Scan NFC Button
              rowButton(
                onPressed: _docIsScanning ? () {} : _startDocNfcSession,
                widgets: [
                  _docIsScanning
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.nfc),
                  const SizedBox(width: 8),
                  Text(
                    _docIsScanning ? "Scanning..." : "Tap NFC Card",
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

              if (!_docTagDetected) ...[
                Text(
                  "Tap your doctor's NFC card to to verify their medical license.",
                  style: bodyTextStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
              ],

              const SizedBox(height: 10),

              // TODO: Remove this section
              Text("Scanned Proof", style: heading2TextStyle),
              const SizedBox(height: 8),
              Text(_docNfcData, style: body2TextStyle),

              const SizedBox(height: 10),

              if (_docTagDetected) ...[
                rowButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VerificationPage(),
                      ),
                    );
                  },
                  widgets: [
                    Text(
                      "Verify",
                      style: buttonTextStyle,
                    ),
                  ],
                  backgroundColor: lightGreenColor,
                  foregroundColor: Colors.black,
                  borderRadius: 8,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
