import 'package:app_frontend/core/utils.dart';
import 'package:app_frontend/features/auth/onboarding_page.dart';
import 'package:flutter/material.dart';

// import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService().init();
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
