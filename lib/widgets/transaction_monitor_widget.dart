// transaction_monitor_page.dart
import 'package:flutter/material.dart';
import '../services/transaction_watch_service.dart';

class TransactionMonitorPage extends StatefulWidget {
  final TransactionMonitorService monitorService;

  const TransactionMonitorPage({required this.monitorService, super.key});

  @override
  State<TransactionMonitorPage> createState() => _TransactionMonitorPageState();
}

class _TransactionMonitorPageState extends State<TransactionMonitorPage> {
  List<Transaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    widget.monitorService.stream.listen((txn) {
      setState(() {
        _transactions.add(txn);
      });
    });
    widget.monitorService.start();
  }

  @override
  void dispose() {
    widget.monitorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Transaction Monitor")),
      body: ListView.builder(
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final txn = _transactions[index];
          return ListTile(
            leading: txn.status == 'pending'
                ? CircularProgressIndicator()
                : Icon(Icons.check_circle, color: Colors.green),
            title: Text("Wallet: ${txn.walletAddress}"),
            subtitle: Text("Txn: ${txn.transactionHash}"),
            trailing: Text(txn.status.toUpperCase()),
          );
        },
      ),
    );
  }
}
