import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
