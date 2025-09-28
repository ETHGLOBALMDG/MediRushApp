import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  final String
      treatmentData; // the new data of the treatment of the patient that needs to be appended to the already existing data on walrus
  final String nfcData;

  const TransactionsPage(
      {super.key, required this.treatmentData, required this.nfcData});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage>
    with WidgetsBindingObserver {
  late final TransactionMonitorService _monitorService;
  int _txnStep = 0; // track which txn user is on (0, 1, 2)

  String _status = "Enter your EVM address to monitor contract events";
  StreamSubscription<Uri>? _linkSubscription;
  Timer? _monitoringTimer;
  final appLinks = AppLinksService();
  final TextEditingController _addressController = TextEditingController();

  bool _isWaitingForCallback = false;
  bool _isMonitoring = false;
  String? _monitoredAddress;
  String? _lastTransactionHash;
  // NOTE: This list now stores simplified EVM event data, not full Hedera transactions
  List<Map<String, dynamic>> _recentTransactions = [];
  bool _hasNetworkConnection = true;
  // int _consecutiveErrors = 0;
  // static const int _maxRetries = 3;

  // Hedera EVM constants
  static const String _dappUrl = 'https://delightful-pasca-9daf52.netlify.app';
  static const String _hederaEvmRpcUrl = 'https://testnet.hashio.io/api';

  final EthereumAddress _contractAddress = EthereumAddress.fromHex(
      '0xb336f276bd3c380c5183a0a2f21e631e4a333d00'); // ⚠️ Your Contract Address
  final String _smartContractAddress =
      "0xb336f276bd3c380c5183a0a2f21e631e4a333d00";

  late Web3Client _web3client;
  int? _lastBlockNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _web3client = Web3Client(_hederaEvmRpcUrl, http.Client());
    _initUniLinks();
    _checkNetworkConnection();

    _monitorService = TransactionMonitorService(
      backendUrl: "https://hedera-tx-monitor-backend.onrender.com",
    );

    // Listen to new transactions
    _monitorService.stream.listen((txn) async {
      final isNew = await TxnHashStorage.isNew(txn.transactionHash);
      if (isNew) {
        await TxnHashStorage.save(txn.transactionHash);
        print("[TransactionsPage] Confirmed new txn: ${txn.transactionHash}");

        if (mounted) {
          setState(() {
            _txnStep++;
          });

          // After 3rd transaction → navigate to review page
          if (_txnStep >= 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ReviewPage(),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Transaction $_txnStep confirmed! Proceed."),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    });

    _monitorService.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNetworkConnection();
      if (_isWaitingForCallback) {
        setState(() {
          _status = "Returned to app. Monitoring for events...";
          _isWaitingForCallback = false;
        });

        if (_monitoredAddress != null) {
          _startMonitoring(_monitoredAddress!);
        }
      }
    }
  }

  Future<void> _checkNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        setState(() {
          _hasNetworkConnection = true;
        });
      }
    } catch (e) {
      setState(() {
        _hasNetworkConnection = false;
        _status = "No internet connection. Please check your network.";
      });
      debugPrint("Network check failed: $e");
    }
  }

  // VALIDATION: Changed to EVM address validation (0x...)
  bool _isValidEvmAddress(String address) {
    final evmRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');
    return evmRegex.hasMatch(address);
  }

  // START MONITORING: Initializes block number and polling timer
  void _startMonitoring(String address) async {
    if (!_isValidEvmAddress(address)) {
      setState(() {
        _status = "Invalid EVM address. Please check and try again.";
      });
      return;
    }

    if (!_hasNetworkConnection) {
      setState(() {
        _status = "Cannot start monitoring: No internet connection";
      });
      return;
    }

    setState(() {
      _monitoredAddress = address;
      _isMonitoring = true;
      _status = "Monitoring Contract Events for: ${address.substring(0, 6)}...";
    });

    try {
      _lastBlockNumber = await _web3client.getBlockNumber();
      await _checkForNewEvents(); // Initial check
    } catch (e) {
      setState(() {
        _status = "Failed to connect to Hedera EVM RPC: $e";
      });
      return;
    }

    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_hasNetworkConnection) {
        _checkForNewEvents();
      } else {
        _checkNetworkConnection();
      }
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Started monitoring contract events for: $address"),
        backgroundColor: Colors.green,
      ),
    );
  }

  // CHECK FOR NEW EVENTS: Uses web3dart.getLogs()
  Future<void> _checkForNewEvents() async {
    if (!_hasNetworkConnection || _lastBlockNumber == null) return;

    try {
      final latestBlock = await _web3client.getBlockNumber();

      if (latestBlock > _lastBlockNumber!) {
        // Prepare filter to check for logs *from* the contract address
        final filterOptions = FilterOptions(
          fromBlock: BlockNum.exact(_lastBlockNumber! + 1),
          toBlock: BlockNum.exact(latestBlock),
          address: _contractAddress,
          topics: const [], // catch all contracts
        );

        final events = await _web3client.getLogs(filterOptions);

        if (events.isNotEmpty) {
          final latestEvent = events.first;
          final currentHash = latestEvent.transactionHash;

          if (_lastTransactionHash == null ||
              currentHash != _lastTransactionHash) {
            _lastTransactionHash = currentHash;
            // Simplified fetch to update the UI list with the new data
            await _fetchRecentTransactions();

            setState(() {
              _status =
                  "New event detected! Tx Hash: ${currentHash?.substring(0, 10)}...";
            });

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("🎉 New smart contract event detected!"),
                backgroundColor: Colors.blue,
              ),
            );
          }
        }
        _lastBlockNumber = latestBlock;
      } else {
        setState(() {
          _status =
              "Monitoring active - Last check: ${DateTime.now().toString().substring(11, 19)}";
        });
      }
    } catch (e) {
      debugPrint("Error checking for new events: $e");
      setState(() {
        _status = "Monitoring paused - connection issues. Retrying...";
      });
    }
  }

  // FETCH TRANSACTIONS: Uses Hedera EVM HashScan/Mirror Node REST API for simplified display data
  Future<void> _fetchRecentTransactions() async {
    try {
      // NOTE: This REST API call is for demonstration/display purposes only,
      // as fetching EVM event *logs* is best done via RPC above.
      final apiUrl =
          'https://testnet.hashscan.io/api/v2/transactions?account.id=$_monitoredAddress&order=desc&limit=5';
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['transactions'] != null && data['transactions'] is List) {
          // Store the raw transaction data for display
          setState(() {
            _recentTransactions =
                List<Map<String, dynamic>>.from(data['transactions']);
          });
        }
      } else {
        debugPrint("Failed to fetch EVM transactions: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching recent transactions: $e");
    }
  }

  // FORMATTING: Convert tinybars to HBAR for UI display
  // String _formatTinybarsToHbar(String tinybars) {
  //   try {
  //     final hbarAmount = BigInt.parse(tinybars) / BigInt.from(10).pow(8);
  //     return hbarAmount.toStringAsFixed(8);
  //   } catch (e) {
  //     return '0';
  //   }
  // }

  // FORMATTING: Hedera timestamp to readable date
  String _formatTimestamp(String timestamp) {
    try {
      final parts = timestamp.split('.');
      final date =
          DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0]) * 1000);
      return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return timestamp;
    }
  }

  void _stopMonitoring() {
    _monitoringTimer?.cancel();
    setState(() {
      _isMonitoring = false;
      _monitoredAddress = null;
      _status = "Monitoring stopped. Enter a new address to start again.";
      _recentTransactions.clear();
      // _consecutiveErrors = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Stopped monitoring wallet"),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _openMetaMask({
    required String functionName,
    required Map<String, dynamic> params,
  }) async {
    // if (_monitoredAddress == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(
    //       content:
    //           Text("Please enter and start monitoring a wallet address first"),
    //       backgroundColor: Colors.red,
    //     ),
    //   );
    //   return;
    // }

    setState(() {
      _status = "Opening MetaMask browser with dApp...";
      _isWaitingForCallback = true;
    });

    // Construct URL with query parameters for contract call
    final queryParams = {
      "contract": _smartContractAddress,
      "function": functionName, // pass which function you want
      "params": jsonEncode(params),
    };

    final uri = Uri.parse(_dappUrl).replace(queryParameters: queryParams);
    final metamaskUrl = 'https://metamask.app.link/dapp/${uri.toString()}';

    try {
      final launchUri = Uri.parse(metamaskUrl);
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);

        setState(() {
          _status = "MetaMask opened with dApp. Monitoring for transactions...";
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "MetaMask opened! Any contract calls will be monitored automatically."),
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e\nPlease make sure MetaMask is installed."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatWeiToEther(String weiString) {
    try {
      final weiAmount = BigInt.parse(weiString);
      final etherAmount = weiAmount / BigInt.from(10).pow(18);
      return etherAmount.toStringAsFixed(6); // 6 decimal places
    } catch (e) {
      return '0';
    }
  }

  Future<void> _initUniLinks() async {
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        _handleIncomingLink(initialUri);
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get initial uri: $e");
      setState(() {
        _status = "Error: Failed to initialize deep links";
      });
    }

    _linkSubscription = appLinks.linkStream.listen(
      (Uri uri) {
        _handleIncomingLink(uri);
      },
      onError: (Object err) {
        debugPrint("Failed to listen for uri: $err");
        setState(() {
          _status = "Error: Deep link listener failed";
        });
      },
    );
  }

  void _handleIncomingLink(Uri uri) {
    debugPrint("Received deep link: $uri");
    _isWaitingForCallback = false;

    if (uri.scheme == "verimed" && uri.host == "callback") {
      final status = uri.queryParameters['status'];
      final txHash = uri.queryParameters['txHash'];
      final error = uri.queryParameters['error'];

      if (status == 'success' && txHash != null) {
        setState(() {
          _status = "Transaction completed! Hash: $txHash";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Transaction hash received: $txHash")),
        );
      } else if (status == 'failure' && error != null) {
        setState(() {
          _status = "Transaction failed: ${Uri.decodeComponent(error)}";
        });
      }
    }
  }

  @override
  void dispose() {
    _monitorService.dispose();

    _linkSubscription?.cancel();
    _monitoringTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _addressController.dispose();
    _web3client.dispose();
    super.dispose();
  }

  /// This simulates sending a transaction for each button
  void _sendTransaction(String function, Map<String, dynamic> params) async {
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Executing $function transaction..."),
      ),
    );
    _openMetaMask(functionName: function, params: params);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Medical History", style: heading2TextStyle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Scanned Data Received:",
                style: TextStyle(fontFamily: "Poppins", fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              widget.treatmentData,
              style:
                  const TextStyle(fontFamily: 'monospace', color: Colors.grey),
            ),
            const SizedBox(height: 30),
            rowButton(
              onPressed: () {
                // the FIRST function call which will fetch us the blob id based on the wallet address and private key that we have
                Map<String, dynamic> jsonData = jsonDecode(widget.nfcData);
                if (_txnStep == 0) _sendTransaction("fetchBlobID", jsonData);
              },
              widgets: [Text("Get Old ID", style: buttonTextStyle)],
              backgroundColor: lightGreenColor,
              foregroundColor: Colors.black,
              borderRadius: 8,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            const SizedBox(height: 10),
            rowButton(
              onPressed: () {
                if (_txnStep == 1) _sendTransaction("updateID", {});
              },
              widgets: [Text("Update Patient ID", style: buttonTextStyle)],
              backgroundColor: lightGreenColor,
              foregroundColor: Colors.black,
              borderRadius: 8,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            const SizedBox(height: 10),
            rowButton(
              onPressed: () {
                if (_txnStep == 2) _sendTransaction("updateBlobID", {});
              },
              widgets: [Text("Update New ID", style: buttonTextStyle)],
              backgroundColor: lightGreenColor,
              foregroundColor: Colors.black,
              borderRadius: 8,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ],
        ),
      ),
    );
  }
}
