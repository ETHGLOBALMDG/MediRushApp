import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:app_frontend/core/utils.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:web3dart/web3dart.dart';
import '../../services/app_links_service.dart';
import '../../services/transaction_watch_service.dart';
import './review_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/themes.dart';

class TransactionsPage extends StatefulWidget {
  final String treatmentData;
  final String nfcData;

  const TransactionsPage(
      {super.key, required this.treatmentData, required this.nfcData});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage>
    with WidgetsBindingObserver {
  late final TransactionMonitorService _monitorService;
  late final TransactionWatcherService _transactionWatcher;

  int _txnStep = 0;
  String _status = "Ready to start medical record update process";

  StreamSubscription<Uri>? _linkSubscription;
  final appLinks = AppLinksService();

  bool _isWaitingForCallback = false;
  bool _hasNetworkConnection = true;
  bool _isProcessingTransaction = false;

  String? _currentTransactionHash;
  String? _oldBlobId;
  String? _newBlobId;

  // Transaction results storage
  Map<String, dynamic> _transactionResults = {};

  // Constants
  static const String _dappUrl = 'https://38a7299c2911.ngrok-free.app';
  static const String _smartContractAddress =
      "0xb336f276bd3c380c5183a0a2f21e631e4a333d00";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  void _initializeServices() {
    _transactionWatcher = TransactionWatcherService();
    _monitorService = TransactionMonitorService(
      backendUrl: "https://hedera-tx-monitor-backend.onrender.com",
    );

    // Listen to new transactions from backend
    _monitorService.stream.listen(_handleNewTransaction);
    _monitorService.start();

    _initUniLinks();
    _checkNetworkConnection();
  }

  Future<void> _handleNewTransaction(dynamic txn) async {
    final transactionHash = txn.transactionHash;

    // Check if this is a new transaction
    final isNew = await TxnHashStorage.isNew(transactionHash);
    if (!isNew) return;

    await TxnHashStorage.save(transactionHash);
    print("[TransactionsPage] Processing new transaction: $transactionHash");

    if (mounted) {
      setState(() {
        _currentTransactionHash = transactionHash;
        _isProcessingTransaction = true;
        _status =
            "Processing transaction: ${transactionHash.substring(0, 10)}...";
      });

      // Poll for transaction receipt and decode results
      await _processTransactionReceipt(transactionHash);
    }
  }

  Future<void> _processTransactionReceipt(String transactionHash) async {
    try {
      setState(() {
        _status = "Waiting for transaction confirmation...";
      });

      // Poll for transaction receipt
      final receipt = await _transactionWatcher
          .monitorTransactionForReceipt(transactionHash);

      if (mounted) {
        setState(() {
          _status = "Transaction confirmed! Decoding results...";
        });

        // Decode transaction results
        final decodedResult =
            _transactionWatcher.decodeTransactionResult(receipt);

        if (decodedResult != null) {
          await _handleTransactionResult(decodedResult, transactionHash);
        } else {
          setState(() {
            _status = "Transaction confirmed but couldn't decode results";
          });
        }

        _completeTransactionStep();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = "Error processing transaction: $e";
          _isProcessingTransaction = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Transaction processing failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleTransactionResult(
      String decodedResult, String transactionHash) async {
    // Store the transaction result
    _transactionResults[transactionHash] = decodedResult;

    // Extract relevant data based on transaction step
    switch (_txnStep) {
      case 0: // fetchBlobID result
        _extractOldBlobId(decodedResult);
        break;
      case 1: // updateID result
        _handlePatientIdUpdate(decodedResult);
        break;
      case 2: // updateBlobID result
        _extractNewBlobId(decodedResult);
        break;
    }

    setState(() {
      _status = "Step ${_txnStep + 1} completed successfully!";
    });
  }

  void _extractOldBlobId(String decodedResult) {
    // Parse the decoded result to extract the old blob ID
    try {
      // Assuming the decoded result contains the blob ID
      final regex = RegExp(r'BlobID:\s*(\S+)');
      final match = regex.firstMatch(decodedResult);
      if (match != null) {
        _oldBlobId = match.group(1);
        print("Extracted old blob ID: $_oldBlobId");
      }
    } catch (e) {
      print("Error extracting old blob ID: $e");
    }
  }

  void _handlePatientIdUpdate(String decodedResult) {
    // Handle patient ID update result
    print("Patient ID update result: $decodedResult");
  }

  void _extractNewBlobId(String decodedResult) {
    // Parse the decoded result to extract the new blob ID
    try {
      final regex = RegExp(r'NewBlobID:\s*(\S+)');
      final match = regex.firstMatch(decodedResult);
      if (match != null) {
        _newBlobId = match.group(1);
        print("Extracted new blob ID: $_newBlobId");
      }
    } catch (e) {
      print("Error extracting new blob ID: $e");
    }
  }

  void _completeTransactionStep() {
    setState(() {
      _txnStep++;
      _isProcessingTransaction = false;
      _currentTransactionHash = null;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Transaction step $_txnStep completed successfully!"),
        backgroundColor: Colors.green,
      ),
    );

    // Navigate to review page after all transactions are complete
    if (_txnStep >= 3) {
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ReviewPage(),
            ),
          );
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNetworkConnection();
      if (_isWaitingForCallback) {
        setState(() {
          _status = "Returned to app. Ready to continue...";
          _isWaitingForCallback = false;
        });
      }
    }
  }

  Future<void> _checkNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      setState(() {
        _hasNetworkConnection =
            result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        if (!_hasNetworkConnection) {
          _status = "No internet connection. Please check your network.";
        }
      });
    } catch (e) {
      setState(() {
        _hasNetworkConnection = false;
        _status = "No internet connection. Please check your network.";
      });
    }
  }

  void _executeTransaction(
      String functionName, Map<String, dynamic> params) async {
    if (_isProcessingTransaction) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please wait for the current transaction to complete"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_hasNetworkConnection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No internet connection available"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _status = "Initiating $functionName transaction...";
    });

    await _openMetaMaskForTransaction(
        functionName: functionName, params: params);
  }

  Future<void> _openMetaMaskForTransaction({
    required String functionName,
    required Map<String, dynamic> params,
  }) async {
    setState(() {
      _status = "Opening MetaMask for $functionName...";
      _isWaitingForCallback = true;
    });

    final queryParams = {
      "contract": _smartContractAddress,
      "function": functionName,
      "params": jsonEncode(params),
    };

    final uri = Uri.parse(_dappUrl).replace(queryParameters: queryParams);
    final metamaskUrl = 'https://metamask.app.link/dapp/${uri.toString()}';

    try {
      final launchUri = Uri.parse(metamaskUrl);
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);

        setState(() {
          _status = "MetaMask opened. Please complete the transaction...";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("MetaMask opened for $functionName transaction"),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        throw Exception("Cannot launch MetaMask");
      }
    } catch (e) {
      setState(() {
        _status = "Error opening MetaMask: $e";
        _isWaitingForCallback = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e\nPlease make sure MetaMask is installed."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _initUniLinks() async {
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        _handleIncomingLink(initialUri);
      }
    } on PlatformException catch (e) {
      setState(() {
        _status = "Error: Failed to initialize deep links";
      });
    }

    _linkSubscription = appLinks.linkStream.listen(
      _handleIncomingLink,
      onError: (Object err) {
        setState(() {
          _status = "Error: Deep link listener failed";
        });
      },
    );
  }

  void _handleIncomingLink(Uri uri) {
    if (!mounted) return;

    _isWaitingForCallback = false;

    if (uri.scheme == "verimed" && uri.host == "callback") {
      final status = uri.queryParameters['status'];
      final txHash = uri.queryParameters['txHash'];
      final error = uri.queryParameters['error'];

      if (status == 'success' && txHash != null) {
        setState(() {
          _status = "Transaction submitted! Waiting for confirmation...";
        });
      } else if (status == 'failure' && error != null) {
        setState(() {
          _status = "Transaction failed: ${Uri.decodeComponent(error)}";
          _isProcessingTransaction = false;
        });
      }
    }
  }

  Widget _buildTransactionStep(int stepNumber, String title,
      String functionName, Map<String, dynamic> params,
      {bool isEnabled = true}) {
    final isCurrentStep = _txnStep == stepNumber;
    final isCompleted = _txnStep > stepNumber;
    final isProcessing = _isProcessingTransaction && isCurrentStep;

    Color backgroundColor = lightGreenColor;
    Color foregroundColor = Colors.black;

    if (isCompleted) {
      backgroundColor = Colors.green;
      foregroundColor = Colors.white;
    } else if (!isEnabled || (!isCurrentStep && !isCompleted)) {
      backgroundColor = Colors.grey.shade300;
      foregroundColor = Colors.grey.shade600;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: rowButton(
        onPressed: isEnabled && isCurrentStep && !isProcessing
            ? () => _executeTransaction(functionName, params)
            : () {},
        widgets: [
          if (isProcessing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (isProcessing) const SizedBox(width: 8),
          if (isCompleted)
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
          if (isCompleted) const SizedBox(width: 8),
          Expanded(
            child: Text(
              isProcessing ? "Processing..." : title,
              style: buttonTextStyle.copyWith(color: foregroundColor),
            ),
          ),
        ],
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        borderRadius: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> jsonData = jsonDecode(widget.nfcData);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Medical History", style: heading2TextStyle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                _status,
                style: const TextStyle(
                  fontFamily: "Poppins",
                  fontSize: 14,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Scanned data display
            Text(
              "Scanned Data Received:",
              style: const TextStyle(fontFamily: "Poppins", fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.treatmentData,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Transaction progress
            Text(
              "Transaction Progress: Step ${_txnStep + 1} of 3",
              style: const TextStyle(
                fontFamily: "Poppins",
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Transaction steps
            _buildTransactionStep(
              0,
              "Get Old Medical Record ID",
              "fetchBlobID",
              jsonData,
              isEnabled: _txnStep == 0,
            ),
            _buildTransactionStep(
              1,
              "Update Patient ID",
              "updateID",
              {"treatmentData": widget.treatmentData},
              isEnabled: _txnStep == 1,
            ),
            _buildTransactionStep(
              2,
              "Store New Medical Record ID",
              "updateBlobID",
              {"oldBlobId": _oldBlobId, "treatmentData": widget.treatmentData},
              isEnabled: _txnStep == 2,
            ),

            const Spacer(),

            // Results summary (if any transactions completed)
            if (_transactionResults.isNotEmpty) ...[
              const Text(
                "Transaction Results:",
                style: TextStyle(
                  fontFamily: "Poppins",
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_oldBlobId != null) Text("Old Blob ID: $_oldBlobId"),
                    if (_newBlobId != null) Text("New Blob ID: $_newBlobId"),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Review button
            rowButton(
              onPressed: _txnStep >= 3
                  ? () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => ReviewPage()),
                      );
                    }
                  : () {},
              widgets: [
                Text(
                  "Leave a Review for the Doctor",
                  style: buttonTextStyle.copyWith(
                    color: _txnStep >= 3 ? Colors.black : Colors.grey,
                  ),
                )
              ],
              backgroundColor:
                  _txnStep >= 3 ? Colors.white : Colors.grey.shade200,
              foregroundColor: _txnStep >= 3 ? Colors.black : Colors.grey,
              borderRadius: 8,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _monitorService.dispose();
    _transactionWatcher.dispose();
    _linkSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
