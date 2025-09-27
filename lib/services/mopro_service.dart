import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:mopro_flutter/mopro_flutter.dart';
import 'package:mopro_flutter/mopro_types.dart';

class MoProService {
  static final MoproFlutter _moproFlutterPlugin = MoproFlutter();

  // --- CIRCOM Proof Functions ---

  /// Generates a Circom proof.
  /// Returns a [CircomProofResult] or throws an [Exception].
  static Future<CircomProofResult?> generateCircomProof({
    required String zkeyPath,
    required String inputsJson,
    ProofLib proofLib = ProofLib.arkworks,
  }) async {
    try {
      final proofResult = _moproFlutterPlugin.generateCircomProof(
        zkeyPath,
        inputsJson,
        proofLib,
      );
      return proofResult;
    } on Exception {
      rethrow;
    }
  }

  /// Verifies a Circom proof.
  /// Returns true if the proof is valid, false otherwise. Throws an [Exception] on error.
  static Future<bool> verifyCircomProof({
    required String zkeyPath,
    required CircomProofResult proofResult,
    ProofLib proofLib = ProofLib.arkworks,
  }) async {
    try {
      final isValid = await _moproFlutterPlugin.verifyCircomProof(
        zkeyPath,
        proofResult,
        proofLib,
      );
      return isValid;
    } on Exception {
      rethrow;
    }
  }
}
