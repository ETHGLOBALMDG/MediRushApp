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
