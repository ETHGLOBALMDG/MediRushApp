import 'dart:async';
import 'package:flutter/services.dart';

class AppLinksService {
  static const _channel = MethodChannel('app.links');
  final _linkController = StreamController<Uri>.broadcast();

  Stream<Uri> get linkStream => _linkController.stream;

  AppLinksService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewLink') {
        final link = call.arguments as String;
        _linkController.add(Uri.parse(link));
      }
    });
  }

  Future<Uri?> getInitialLink() async {
    final link = await _channel.invokeMethod<String>('getInitialLink');
    if (link != null) return Uri.parse(link);
    return null;
  }
}
