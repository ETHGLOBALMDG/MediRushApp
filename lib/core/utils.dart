import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

// -----------------------------------------------------------
// FUNCTIONS
// -----------------------------------------------------------

/// Converts a scanned QR code string back to the original string.
/// Assumes the QR code string is Base64-encoded GZip-compressed data.
String decodeQrString(String qrData) {
  try {
    // 1. Base64 decode to get compressed bytes
    List<int> compressedBytes = base64Decode(qrData);

    // 2. GZip decompress to get original UTF-8 bytes
    List<int> decompressedBytes = GZipDecoder().decodeBytes(compressedBytes);

    // 3. Convert UTF-8 bytes to string
    return utf8.decode(decompressedBytes);
  } catch (e) {
    // Handle errors gracefully
    print("Error decoding QR string: $e");
    return "";
  }
}

String parseNfc(String url) {
  try {
    var result = url.trim();

    // Remove protocol
    if (result.startsWith('http://')) {
      result = result.substring(7);
    } else if (result.startsWith('https://')) {
      result = result.substring(8);
    }

    // Remove www.
    if (result.startsWith('www.')) {
      result = result.substring(4);
    }

    // Remove .com at the end
    if (result.endsWith('.com')) {
      result = result.substring(0, result.length - 4);
    }

    return result;
  } catch (e) {
    print('Error stripping URL: $e');
    return url;
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

String getFormattedDateString() {
  // 1. Get the current date and time
  DateTime now = DateTime.now();

  // 2. Define the desired format: dd-MM-yyyy
  // Note: 'MM' is for the month number with leading zero padding.
  DateFormat formatter = DateFormat('dd-MM-yyyy');

  // 3. Format the date
  String formattedDate = formatter.format(now);

  return formattedDate;
}

String decodeJsonFromUrl(String restrictedUrl) {
  // 2. Isolate the Encoded Component (the part between the fixed strings)
  String encodedData = parseNfc(restrictedUrl);

  // 3. URL-Decode the Data
  // This converts percent-encoded characters (like %7B) back to their originals ({)
  String jsonString = Uri.decodeComponent(encodedData);

  // 4. Parse the Final JSON String
  return jsonString;
}

/// Adds the "http://" prefix and the ".com" suffix to a given string.
///
/// Example: makeUrl("google") returns "http://google.com"
String makeUrl(String input) {
  // Use string interpolation for a clear and readable construction.
  return 'http://$input.com';
}

// -----------------------------------------------------------
// CLASSES
// -----------------------------------------------------------

class WalletAddrService {
  static const String _addressKey = 'user_wallet_address';

  Future<void> init() async {
    // Shared preferences must be initialized before use
    // In many Flutter apps, SharedPreferences.getInstance() is called here
  }

  Future<bool> setAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_addressKey, address);
  }

  // MODIFIED: Made the method asynchronous (returns Future<String?>)
  Future<String?> getAddress() async {
    final prefs = await SharedPreferences.getInstance();
    // Retrieve the string value associated with the key
    return prefs.getString(_addressKey);
  }
}

class SyncDateService {
  // Keys for storing the two separate date strings
  static const String _readDateKey = 'last_read_date';
  static const String _writeDateKey = 'last_write_date';

  Future<void> init() async {
    // Initialization logic, if needed, would go here.
  }

  // ------------------------- LAST READ DATE METHODS -------------------------

  /// Stores the date of the last successful data read (e.g., "28-09-2025").
  /// Returns true if the operation was successful.
  Future<bool> setLastReadDate(String dateString) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_readDateKey, dateString);
  }

  /// Retrieves the last successful read date string.
  /// Returns the date string (dd-mm-yyyy) or null if not found.
  Future<String?> getLastReadDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_readDateKey);
  }

  // ------------------------- LAST WRITE DATE METHODS ------------------------

  /// Stores the date of the last successful data write (e.g., "28-09-2025").
  /// Returns true if the operation was successful.
  Future<bool> setLastWriteDate(String dateString) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_writeDateKey, dateString);
  }

  /// Retrieves the last successful write date string.
  /// Returns the date string (dd-mm-yyyy) or null if not found.
  Future<String?> getLastWriteDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_writeDateKey);
  }
}

// Define a simple structure for the result data
class BackendTxnResult {
  final String status; // 'monitoring', 'complete', or 'failure'
  final String? txHash; // Transaction hash if submitted
  final String?
      resultData; // The fetched Blob ID (for View calls) or function output
  final String? errorMessage;

  BackendTxnResult({
    required this.status,
    this.txHash,
    this.resultData,
    this.errorMessage,
  });

  factory BackendTxnResult.fromJson(Map<String, dynamic> json) {
    return BackendTxnResult(
      status: json['status'] ?? 'unknown',
      txHash: json['txHash'],
      resultData: json['data'], // Maps to the 'data' field from your DApp POST
      errorMessage: json['error'],
    );
  }
}

class TransactionWatcherService {
  // ⚠️ Replace with the actual Hedera Testnet RPC URL
  final String _hederaEvmRpcUrl = 'https://testnet.hashio.io/api';
  final Web3Client _web3client;

  // You would need the contract ABI to decode function outputs/events
  final String _contractAbiJson = '...';

  TransactionWatcherService()
      : _web3client = Web3Client(
          'https://testnet.hashio.io/api', // Use a static RPC for polling
          http.Client(),
        );

  /// Starts polling the Hedera EVM network for a transaction receipt.
  /// This simulates the job of the backend monitor, but runs on the client.
  ///
  /// Returns the transaction receipt once the transaction is mined.
  Future<TransactionReceipt> monitorTransactionForReceipt(String txHash) async {
    // Convert the transaction hash string to the required format
    final transactionHash = Uint8List.fromList(hexToBytes(txHash));

    // Polling logic: Check the network until the receipt is found
    for (int i = 0; i < 60; i++) {
      // Polls for up to 60 * 5 = 300 seconds (5 minutes)
      try {
        // 1. Ask the EVM node for the receipt
        String hashString = bytesToHex(transactionHash, include0x: true);

        final receipt = await _web3client.getTransactionReceipt(hashString);

        if (receipt != null) {
          debugPrint('Transaction mined! Hash: $txHash');
          return receipt;
        }
      } catch (e) {
        // Log error but continue polling if the node is having temporary issues
        debugPrint('Error polling for receipt (attempt $i): $e');
      }

      // 2. Wait before the next poll
      await Future.delayed(const Duration(seconds: 5));
    }

    throw TimeoutException('Transaction receipt not found after 5 minutes.');
  }

  /// Helper function to decode the output of a specific transaction receipt.
  /// This requires the full ABI of your contract.

  String? decodeTransactionResult(TransactionReceipt receipt) {
    try {
      final contract = DeployedContract(
        ContractAbi.fromJson(_contractAbiJson, 'YourContractName'),
        // Use a robust fallback for contractAddress
        EthereumAddress.fromHex(receipt.contractAddress?.hex ??
            '0x0000000000000000000000000000000000000000'),
      );

      // Assume the event you are interested in is named 'BlobIDUpdated'
      final eventDefinition = contract.event('BlobIDUpdated');

      for (final log in receipt.logs) {
        final List<Uint8List> logTopics = log.topics != null
            ? log.topics!.map((topic) {
                // Cast the topic to EthereumAddress and access the bytes property
                // This is necessary if the compiler is treating 'topic' as Object or String
                final EthereumAddress address = topic as EthereumAddress;
                return address.addressBytes;
              }).toList()
            : [];
// 1. Prepare log.data (The third argument needed for decodeResults)
        final logData = log.data ??
            Uint8List(0); // ⬅️ Correctly handle log data as Uint8List

// 2. Prepare log.topics (Conversion logic remains the same)
        final List<String> hexLogTopics = logTopics.map((bytes) {
          // bytesToHex is required for this conversion
          return bytesToHex(bytes, include0x: true);
        }).toList();

// 3. CORRECTED CALL: Pass the list of hex topics and the raw log data
        final decodedLog =
            eventDefinition.decodeResults(hexLogTopics, logData.toString());

        // Check if the log was successfully decoded by the target event
        if (decodedLog.isNotEmpty) {
          // Return a string representation of the decoded event
          // Use .toString() on each decoded argument for safe concatenation
          final patientId = decodedLog[0].toString();
          final newBlobId = decodedLog[1].toString();

          return 'Event: ${eventDefinition.name}, PatientID: $patientId, NewBlobID: $newBlobId';
        }
      }
    } catch (e) {
      debugPrint('Error decoding receipt logs: $e');
    }

    return null;
  }

  // Helper function required by web3dart
  Uint8List hexToBytes(String hex) {
    if (hex.startsWith('0x')) {
      hex = hex.substring(2);
    }
    return Uint8List.fromList(List<int>.generate(hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
  }

  void dispose() {
    _web3client.dispose();
  }
}
