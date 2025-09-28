import 'package:app_frontend/core/utils.dart';
import 'package:app_frontend/features/auth/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // ⬅️ Import Google Fonts

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
      debugShowCheckedModeBanner: false,
      // ⬅️ Set the theme property
      theme: ThemeData(
        // Apply Poppins to the default text theme
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
        // Optionally set the font family for widgets that rely on the primary font
        fontFamily: GoogleFonts.poppins().fontFamily,

        // Define primary colors, brightness, etc.
        // brightness: Brightness.light,
        // colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const OnboardingPage(),
    );
  }
}
