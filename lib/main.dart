import 'package:app_frontend/features/auth/connect_wallet_page.dart';
import 'package:app_frontend/features/auth/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

import 'features/patient/transactions_page.dart';

// import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService().init(); // Initialize the service
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const OnboardingPage(),
    );
  }
}
