import 'package:flutter/material.dart';
import '../../services/transaction_watch_service.dart';
import './review_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/themes.dart';

class TransactionsPage extends StatefulWidget {
  final String recordData;

  const TransactionsPage({super.key, required this.recordData});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late final TransactionMonitorService _monitorService;
  int _txnStep = 0; // track which txn user is on (0, 1, 2)

  @override
  void initState() {
    super.initState();
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
  void dispose() {
    _monitorService.dispose();
    super.dispose();
  }

  /// This simulates sending a transaction for each button
  void _sendTransaction(String label) async {
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Executing $label transaction..."),
      ),
    );

    // 🔹 Here you would actually call your _openMetaMask function
    // For demo purposes, we just wait for monitor to detect the txn
    // await _openMetaMask(contractAddress, fnName, params)
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
              widget.recordData,
              style:
                  const TextStyle(fontFamily: 'monospace', color: Colors.grey),
            ),
            const SizedBox(height: 30),
            rowButton(
              onPressed: () {
                if (_txnStep == 0) _sendTransaction("Get Old ID");
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
                if (_txnStep == 1) _sendTransaction("Update Patient ID");
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
                if (_txnStep == 2) _sendTransaction("Update New ID");
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

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  static const _hashKey = 'my_hash_key';

  late final SharedPreferences _prefs;

  LocalStorageService._internal();
  factory LocalStorageService() => _instance;

  Future<void> init() async => _prefs = await SharedPreferences.getInstance();

  Future<bool> setHash(String hash) => _prefs.setString(_hashKey, hash);

  String? getHash() => _prefs.getString(_hashKey);

  Future<bool> removeHash() => _prefs.remove(_hashKey);

  Future<bool> changeHash(String newHash) async {
    await _prefs.remove(_hashKey);
    return _prefs.setString(_hashKey, newHash);
  }
}
