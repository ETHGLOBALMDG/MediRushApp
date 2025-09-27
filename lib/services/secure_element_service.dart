// File: lib/services/secure_element_service.dart
import 'package:flutter/services.dart';

class SecureElementService {
  static const MethodChannel _channel = MethodChannel('secure_element');

  static Future<String> challengeCard(String challenge) async {
    try {
      final result = await _channel.invokeMethod('challengeCard', {
        'challenge': challenge,
      });
      return result;
    } catch (e) {
      throw Exception('Secure element challenge failed: $e');
    }
  }

  static Future<bool> verifyCardSignature(
      String message, String signature, String publicKey) async {
    try {
      final result = await _channel.invokeMethod('verifySignature', {
        'message': message,
        'signature': signature,
        'publicKey': publicKey,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }
}
