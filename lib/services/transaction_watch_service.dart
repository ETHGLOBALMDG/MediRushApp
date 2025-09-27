// transaction_monitor_service.dart
// txn_hash_storage.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Transaction {
  final int id;
  final String walletAddress;
  final String transactionHash;
  final String status;

  Transaction(this.id, this.walletAddress, this.transactionHash, this.status);

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      json['id'],
      json['walletAddress'],
      json['transactionHash'],
      json['status'] ?? 'unknown',
    );
  }
}

class TransactionMonitorService {
  final String backendUrl;
  int lastId = 0;
  final Duration pollInterval;

  TransactionMonitorService({
    required this.backendUrl,
    this.pollInterval = const Duration(seconds: 3),
  });

  final StreamController<Transaction> _controller =
      StreamController.broadcast();

  Stream<Transaction> get stream => _controller.stream;

  void start() {
    print(
        "[TransactionMonitor] Starting polling every ${pollInterval.inSeconds} seconds...");
    Timer.periodic(pollInterval, (_) => _poll());
  }

  void _poll() async {
    try {
      print("[TransactionMonitor] Polling backend with lastId=$lastId...");
      final response =
          await http.get(Uri.parse("$backendUrl/poll-tx?lastId=$lastId"));

      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        print("[TransactionMonitor] Found ${data.length} new transaction(s)");

        for (var item in data) {
          final txn = Transaction.fromJson(item);

          // ✅ Check with persistent storage if this txn is new
          final isNew = await TxnHashStorage.isNew(txn.transactionHash);
          if (isNew) {
            await TxnHashStorage.save(txn.transactionHash);
            _controller.add(txn); // broadcast to listeners
            print(
                "[TransactionMonitor] New transaction saved: ${txn.transactionHash}");
          } else {
            print(
                "[TransactionMonitor] Duplicate transaction ignored: ${txn.transactionHash}");
          }

          lastId = txn.id; // update lastId regardless
        }
      } else {
        print(
            "[TransactionMonitor] Poll failed with status ${response.statusCode}");
      }
    } catch (e) {
      print("[TransactionMonitor] Poll error: $e");
    }
  }

  void dispose() {
    print("[TransactionMonitor] Disposing service...");
    _controller.close();
  }
}

class TxnHashStorage {
  static const _key = 'last_seen_txn_hash';

  /// Save the latest transaction hash
  static Future<void> save(String txnHash) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, txnHash);
    print("[TxnHashStorage] Saved hash: $txnHash");
  }

  /// Get the last saved transaction hash (null if none yet)
  static Future<String?> getLastHash() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  /// Check if the given txnHash is new compared to the last one
  static Future<bool> isNew(String txnHash) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_key);
    return last != txnHash;
  }

  /// Clear the stored hash
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    print("[TxnHashStorage] Cleared last hash");
  }
}
