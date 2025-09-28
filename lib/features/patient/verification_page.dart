import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mopro_flutter/mopro_flutter.dart';
import 'package:mopro_flutter/mopro_types.dart';
import 'package:app_frontend/core/themes.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';

class VerificationPage extends StatefulWidget {
  final DoctorCredentials credentials;

  const VerificationPage({
    super.key,
    required this.credentials,
  });

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  bool _isVerifying = false;
  bool? _isVerified;
  String? _errorMessage;
  CircomProofResult? _proofResult;
  String _status = "Ready to verify credentials";

  @override
  void initState() {
    super.initState();
    // Auto-verify if credentials are provided
    if (widget.credentials != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyCredentials();
      });
    }
  }

  Future<void> _verifyCredentials() async {
    if (widget.credentials == null) {
      setState(() {
        _errorMessage = "No credentials provided for verification";
        _isVerified = false;
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _isVerified = null;
      _status = "Initializing verification...";
    });

    try {
      // Step 1: Prepare inputs for Circom proof
      setState(() {
        _status = "Preparing proof inputs...";
      });

      final inputs = await _prepareCircomInputs(widget.credentials!);

      // Step 2: Generate Circom proof
      setState(() {
        _status = "Generating ZK proof...";
      });

      final proofResult = await MoProService.generateCircomProof(
        zkeyPath:
            'assets/doctor_verification_final.zkey', // Your verification circuit
        inputsJson: jsonEncode(inputs),
        proofLib: ProofLib.arkworks,
      );

      if (proofResult == null) {
        throw Exception("Failed to generate proof");
      }

      _proofResult = proofResult;

      // Step 3: Verify the generated proof
      setState(() {
        _status = "Verifying proof...";
      });

      final isValid = await MoProService.verifyCircomProof(
        zkeyPath: 'assets/verification.zkey',
        proofResult: proofResult,
        proofLib: ProofLib.arkworks,
      );

      setState(() {
        _isVerified = isValid;
        _status = isValid
            ? "Credentials verified successfully!"
            : "Verification failed";
        _isVerifying = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Verification error: ${e.toString()}";
        _isVerified = false;
        _isVerifying = false;
        _status = "Verification failed";
      });
    }
  }

  Future<Map<String, dynamic>> _prepareCircomInputs(
      DoctorCredentials credentials) async {
    return {
      "doctorId": _stringToFieldElement(credentials.doctorId),
      "publicKey": _stringToFieldElement(credentials.publicKey),
      "medicalLicense": _stringToFieldElement(credentials.medicalLicense),
      "issueDate": _dateToFieldElement(credentials.issueDate),
      "expiryDate": _dateToFieldElement(credentials.expiryDate),
      "signature": _stringToFieldElement(credentials.signature),
      "issuerPubKey": _stringToFieldElement(credentials.issuerPubKey),
      "currentTimestamp": _dateToFieldElement(DateTime.now()),
    };
  }

  String _stringToFieldElement(String input) {
    // Convert string to field element (simplified - adjust based on your circuit)
    final bytes = utf8.encode(input);
    final hash = sha256.convert(bytes);
    final hashInt = hash.bytes.fold<BigInt>(BigInt.zero,
        (prev, byte) => prev * BigInt.from(256) + BigInt.from(byte));

    // Ensure it fits in the field (mod prime)
    const fieldPrime =
        "21888242871839275222246405745257275088548364400416034343698204186575808495617";
    final prime = BigInt.parse(fieldPrime);
    return (hashInt % prime).toString();
  }

  String _dateToFieldElement(DateTime date) {
    // Convert date to Unix timestamp as field element
    return date.millisecondsSinceEpoch.toString();
  }

  Widget _buildCredentialInfo() {
    if (widget.credentials == null) return Container();

    final creds = widget.credentials!;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Doctor Credentials",
              style: heading2TextStyle,
            ),
            const SizedBox(height: 16),
            _buildInfoRow("Doctor ID", creds.doctorId),
            _buildInfoRow("License Number", creds.medicalLicense),
            _buildInfoRow("Issue Date", _formatDate(creds.issueDate)),
            _buildInfoRow("Expiry Date", _formatDate(creds.expiryDate)),
            _buildInfoRow("Status", creds.isExpired ? "Expired" : "Valid"),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  Widget _buildVerificationStatus() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_isVerifying) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _status,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ] else if (_isVerified == true) ...[
              const Icon(
                Icons.verified_user,
                color: Colors.green,
                size: 80,
              ),
              const SizedBox(height: 16),
              Text(
                "VERIFIED",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Doctor credentials have been cryptographically verified using zero-knowledge proofs.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ] else if (_isVerified == false) ...[
              const Icon(
                Icons.cancel,
                color: Colors.red,
                size: 80,
              ),
              const SizedBox(height: 16),
              Text(
                "NOT VERIFIED",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? "Credentials could not be verified.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Icon(
                Icons.help_outline,
                color: Colors.grey,
                size: 80,
              ),
              const SizedBox(height: 16),
              const Text(
                "PENDING VERIFICATION",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Click verify to check credentials",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProofDetails() {
    if (_proofResult == null) return Container();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ZK Proof Details",
              style: heading2TextStyle,
            ),
            const SizedBox(height: 16),
            Text(
              "Proof Generated Successfully",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "The zero-knowledge proof confirms the validity of the doctor's credentials without revealing sensitive information.",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text("Technical Details"),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "Proof Length: ${_proofResult!.proof.toString().length} characters"),
                      const SizedBox(height: 4),
                      Text(
                          "Public Signals: ${_proofResult!.toString().length} values"),
                      const SizedBox(height: 8),
                      const Text(
                        "Proof Hash (first 64 chars):",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _proofResult!.proof.toString().length > 64
                            ? "${_proofResult!.proof.toString().substring(0, 64)}..."
                            : _proofResult!.proof.toString(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          backgroundColor: Colors.white,
          elevation: 1,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildCredentialInfo(),
              _buildVerificationStatus(),
              if (!_isVerifying && widget.credentials != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _verifyCredentials,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lightGreenColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _isVerified == null
                            ? "Verify Credentials"
                            : "Re-verify Credentials",
                        style: buttonTextStyle,
                      ),
                    ),
                  ),
                ),
              _buildProofDetails(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced MoProService with better error handling
class MoProService {
  static final MoproFlutter _moproFlutterPlugin = MoproFlutter();

  /// Generates a Circom proof with enhanced error handling
  static Future<CircomProofResult?> generateCircomProof({
    required String zkeyPath,
    required String inputsJson,
    ProofLib proofLib = ProofLib.arkworks,
  }) async {
    try {
      print("Generating Circom proof with inputs: $inputsJson");

      final proofResult = await _moproFlutterPlugin.generateCircomProof(
        zkeyPath,
        inputsJson,
        proofLib,
      );

      print("Proof generated successfully");
      return proofResult;
    } catch (e) {
      print("Error generating proof: $e");
      rethrow;
    }
  }

  /// Verifies a Circom proof with enhanced error handling
  static Future<bool> verifyCircomProof({
    required String zkeyPath,
    required CircomProofResult proofResult,
    ProofLib proofLib = ProofLib.arkworks,
  }) async {
    try {
      print("Verifying Circom proof...");

      final isValid = await _moproFlutterPlugin.verifyCircomProof(
        zkeyPath,
        proofResult,
        proofLib,
      );

      print("Proof verification result: $isValid");
      return isValid;
    } catch (e) {
      print("Error verifying proof: $e");
      rethrow;
    }
  }
}

// Keep the existing classes for compatibility
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
