import 'dart:convert';
import 'package:archive/archive.dart';

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

String _parseNdefUri(String url) {
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
