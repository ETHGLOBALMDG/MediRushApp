import 'package:web3dart/web3dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../services/app_links_service.dart';

class ConnectWalletPage extends StatefulWidget {
  const ConnectWalletPage({super.key});

  @override
  _ConnectWalletPageState createState() => _ConnectWalletPageState();
}

class _ConnectWalletPageState extends State<ConnectWalletPage>
    with WidgetsBindingObserver {
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
  final String _functionName = "generateKey";

  late Web3Client _web3client;
  int? _lastBlockNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _web3client = Web3Client(_hederaEvmRpcUrl, http.Client());
    _initUniLinks();
    _checkNetworkConnection();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _monitoringTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _addressController.dispose();
    _web3client.dispose();
    super.dispose();
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
    Map<String, dynamic>? params,
  }) async {
    if (_monitoredAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Please enter and start monitoring a wallet address first"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _status = "Opening MetaMask browser with dApp...";
      _isWaitingForCallback = true;
    });

    // Construct URL with query parameters for contract call
    final queryParams = {
      "contract": _smartContractAddress,
      "function": functionName, // pass which function you want
    };

    if (params != null) {
      queryParams["params"] = jsonEncode(params);
    }

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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hedera Wallet Monitor',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Hedera Wallet Monitor'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(
                _hasNetworkConnection ? Icons.wifi : Icons.wifi_off,
                color: _hasNetworkConnection ? Colors.green : Colors.red,
              ),
            ),
            if (_isMonitoring)
              IconButton(
                onPressed: _stopMonitoring,
                icon: const Icon(Icons.stop_circle),
                tooltip: 'Stop Monitoring',
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.account_balance_wallet,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 20),
              if (!_hasNetworkConnection)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.red),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'No internet connection. Monitoring paused.',
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: _checkNetworkConnection,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wallet Address',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          hintText: '0.0.123456',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.account_balance_wallet),
                        ),
                        enabled: !_isMonitoring,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: (_isMonitoring || !_hasNetworkConnection)
                            ? null
                            : () {
                                if (_addressController.text.isNotEmpty) {
                                  _startMonitoring(
                                      _addressController.text.trim());
                                }
                              },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Monitoring'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: _isMonitoring
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  border: Border.all(
                    color: _isMonitoring ? Colors.green : Colors.grey,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isMonitoring
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: _isMonitoring ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isMonitoring
                              ? 'Monitoring Active'
                              : 'Not Monitoring',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isMonitoring ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: (_isMonitoring && _hasNetworkConnection)
                    ? () {
                        _openMetaMask(
                          functionName: "yourFunctionName",
                          params: {"param1": "value1"}, // optional
                        );
                      }
                    : null,
                icon: const Icon(Icons.launch),
                label: const Text('Open dApp in MetaMask Browser'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              if (_recentTransactions.isNotEmpty) ...[
                const Text(
                  'Recent Transactions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentTransactions.length,
                  itemBuilder: (context, index) {
                    final tx = _recentTransactions[index];
                    final transfers = tx['transfers'] as List<dynamic>?;
                    final hbarTransfers = transfers
                            ?.where(
                                (transfer) => transfer['is_approval'] == false)
                            .toList() ??
                        [];

                    String fromAddress = '';
                    String toAddress = '';
                    String amount = '';

                    // Find the primary transfer
                    if (hbarTransfers.isNotEmpty) {
                      final primaryTransfer = hbarTransfers.firstWhere(
                          (t) => t['amount'] != null,
                          orElse: () => null);
                      if (primaryTransfer != null) {
                        fromAddress = hbarTransfers.firstWhere(
                                (t) => t['amount'] < 0)['account_id'] ??
                            '';
                        toAddress = primaryTransfer['account_id'] ?? '';
                        amount = _formatWeiToEther(
                            primaryTransfer['amount'].abs().toString());
                      }
                    }

                    final isOutgoing = fromAddress == _monitoredAddress;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          isOutgoing
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: isOutgoing ? Colors.red : Colors.green,
                        ),
                        title: Text(
                          '${isOutgoing ? 'Sent' : 'Received'} $amount HBAR',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Tx ID: ${tx['transaction_id'].toString().substring(0, 20)}...'),
                            Text(
                                '${isOutgoing ? 'To' : 'From'}: ${(isOutgoing ? toAddress : fromAddress).toString().substring(0, 20)}...'),
                            Text(
                                'Time: ${_formatTimestamp(tx['consensus_timestamp'])}'),
                            if (tx['result'] == 'SUCCESS')
                              const Text('✅ Confirmed',
                                  style: TextStyle(color: Colors.green))
                            else
                              const Text('❌ Failed',
                                  style: TextStyle(color: Colors.red)),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: tx['transaction_id']));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Transaction ID copied to clipboard')),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

//    /**
//      * @notice Updates the blob ID for an existing patient.
//      * @param _patientID The ID of the patient to update.
//      * @param _newBlobID The new blob ID to associate with the patient.
//      */
//     function updateBlobID(uint256 _patientID, string memory _newBlobID) public onlyRegisteredPatient {
//         require(bytes(patientDetailsinBlob[_patientID]).length > 0, "Patient ID not found.");
//         patientDetailsinBlob[_patientID] = _newBlobID;
//         emit BlobIDUpdated(_patientID, _newBlobID);
//     }
//     /**
//      * @notice Updates a patient's ID, moving their record to a new ID.
//      * @param _prevID The current ID of the patient.
//      * @param _newID The new ID to assign to the patient.
//      */
//     function updateID(uint256 _prevID, uint256 _newID) public onlyRegisteredPatient {
//         require(bytes(patientDetailsinBlob[_prevID]).length > 0, "Previous Patient ID not found.");
//         require(bytes(patientDetailsinBlob[_newID]).length == 0, "New Patient ID is already in use.");
//         // Copy the blob ID to the new patient ID
//         patientDetailsinBlob[_newID] = patientDetailsinBlob[_prevID];
//         // Delete the old record
//         delete patientDetailsinBlob[_prevID];
//         emit PatientIDUpdated(_prevID, _newID);
//     }
//     /**
//      * @notice Fetches the blob ID for a given patient ID.
//      * @param _patientID The ID of the patient to look up.
//      * @return The blob ID string associated with the patient.
//      */
//     function fetchBlobID(uint256 _patientID) public view onlyRegisteredPatient returns (string memory) {
//         require(bytes(patientDetailsinBlob[_patientID]).length > 0, "Patient ID not found.");
//         return patientDetailsinBlob[_patientID];
//     }
// }
