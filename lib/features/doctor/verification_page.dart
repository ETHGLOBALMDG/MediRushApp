import 'dart:convert';

import 'package:app_frontend/core/themes.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  static String _parseNdefUri(String url) {
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

  static DoctorCredentials? _parseCredentialsFromUrl(String url) {
    try {
      print('Parsing URL: $url');

      // Extract base64 data from URL
      final uri = Uri.parse(url);
      final base64Data =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';

      if (base64Data.isEmpty) {
        print('No base64 data found in URL');
        return null;
      }

      print('Extracted base64 data: $base64Data');

      // Decode and parse JSON
      final decodedBytes = base64.decode(base64Data);
      final jsonString = utf8.decode(decodedBytes);
      print('Decoded JSON: $jsonString');

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      return DoctorCredentials.fromCompressed(data);
    } catch (e) {
      print('URL parsing error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "License Verification",
            style: headingTextStyle,
          ),
        ),
        body: Padding(
          padding: EdgeInsetsGeometry.all(12),
        ),
      ),
    );
  }
}

class DoctorCredentials {
  final String doctorId;
  final String publicKey;
  final String medicalLicense;
  final DateTime issueDate;
  final DateTime expiryDate;
  final String signature;
  final String issuerPubKey;

  DoctorCredentials({
    required this.doctorId,
    required this.publicKey,
    required this.medicalLicense,
    required this.issueDate,
    required this.expiryDate,
    required this.signature,
    required this.issuerPubKey,
  });

  factory DoctorCredentials.fromCompressed(Map<String, dynamic> data) {
    return DoctorCredentials(
      doctorId: data['d'] ?? '',
      publicKey: data['k'] ?? '',
      medicalLicense: data['l'] ?? '',
      issueDate: _parseDate(data['i'] ?? ''),
      expiryDate: _parseDate(data['e'] ?? ''),
      signature: data['s'] ?? '',
      issuerPubKey: data['p'] ?? '',
    );
  }

  static DateTime _parseDate(String dateStr) {
    if (dateStr.length == 8) {
      try {
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        return DateTime(year, month, day);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  bool get isExpired => DateTime.now().isAfter(expiryDate);
  bool get isValid => !isExpired && doctorId.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'doctorId': doctorId,
      'publicKey': publicKey,
      'medicalLicense': medicalLicense,
      'issueDate': issueDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'signature': signature,
      'issuerPubKey': issuerPubKey,
    };
  }
}

// Mock ZK Service (replace with actual mopro integration)
class ZKService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Mock initialization - in real implementation, load mopro circuits
    await Future.delayed(Duration(milliseconds: 500));
    _isInitialized = true;
    print('ZK Service initialized (mock)');
  }

  static Future<ZKProofResult> generateProof({
    required DoctorCredentials credentials,
    required String privateKey,
    required int challengeNonce,
  }) async {
    if (!_isInitialized) await initialize();

    print('Generating ZK proof for doctor: ${credentials.doctorId}');

    // Mock proof generation - replace with actual mopro implementation
    await Future.delayed(Duration(seconds: 2));

    try {
      // Mock validation logic
      final isValid =
          _mockValidateCredentials(credentials, privateKey, challengeNonce);

      // Generate mock proof
      final mockProof = _generateMockProof(credentials, challengeNonce);

      return ZKProofResult(
        proof: mockProof,
        publicSignals: {
          'isValid': isValid ? '1' : '0',
          'doctorId': credentials.doctorId,
          'challengeNonce': challengeNonce.toString(),
        },
        isValid: isValid,
      );
    } catch (e) {
      return ZKProofResult(
        proof: '',
        publicSignals: {},
        isValid: false,
        error: e.toString(),
      );
    }
  }

  static Future<bool> verifyProof(ZKProofResult proofResult) async {
    if (!_isInitialized) await initialize();

    print('Verifying ZK proof...');

    // Mock verification - replace with actual mopro verification
    await Future.delayed(Duration(milliseconds: 500));

    try {
      // In real implementation, this would verify the ZK proof cryptographically
      final isValid = proofResult.publicSignals['isValid'] == '1';
      print('Proof verification result: $isValid');
      return isValid;
    } catch (e) {
      print('Proof verification error: $e');
      return false;
    }
  }

  static bool _mockValidateCredentials(
      DoctorCredentials credentials, String privateKey, int challengeNonce) {
    // Mock validation logic - replace with actual cryptographic validation
    return credentials.isValid && privateKey.isNotEmpty && challengeNonce > 0;
  }

  static String _generateMockProof(
      DoctorCredentials credentials, int challengeNonce) {
    // Generate a mock proof string - replace with actual ZK proof
    final proofData =
        '${credentials.doctorId}:$challengeNonce:${DateTime.now().millisecondsSinceEpoch}';
    final bytes = utf8.encode(proofData);
    final hash = sha256.convert(bytes);
    return base64.encode(hash.bytes);
  }
}

class ZKProofResult {
  final String proof;
  final Map<String, String> publicSignals;
  final bool isValid;
  final String? error;

  ZKProofResult({
    required this.proof,
    required this.publicSignals,
    required this.isValid,
    this.error,
  });
}
