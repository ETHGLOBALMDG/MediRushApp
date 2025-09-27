import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import '../../core/themes.dart';
import '../../core/utils.dart';
import '../doctor/doctor_nfc_page.dart';
import 'connect_wallet_page.dart';
import '../patient/link_doctor_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<PageViewModel> pages = [
      PageViewModel(
        title: "Scan Doctor Details",
        body:
            "Patients can quickly scan their doctor’s QR code to get verified details instantly.",
        image: const Icon(Icons.qr_code_scanner_rounded,
            size: 120, color: Colors.black),
        decoration: const PageDecoration(
          titleTextStyle: headingTextStyle,
          bodyTextStyle: body2TextStyle,
        ),
      ),
      PageViewModel(
        title: "Medical History via NFC",
        body:
            "Send and receive medical history securely using NFC-enabled cards.",
        image: const Icon(Icons.nfc_rounded, size: 120, color: Colors.black),
        decoration: const PageDecoration(
          titleTextStyle: headingTextStyle,
          bodyTextStyle: body2TextStyle,
        ),
      ),
      PageViewModel(
        title: "Choose Your Role",
        bodyWidget: const _ChooseRoleSlide(),
        image: const Icon(Icons.person_rounded, size: 120, color: Colors.black),
        decoration: const PageDecoration(
          titleTextStyle: headingTextStyle,
          contentMargin:
              EdgeInsets.zero, // Remove default padding for custom widget
          fullScreen: false,
        ),
      ),
      // ⚠️ NEW PAGE: The custom widget for wallet submission
      PageViewModel(
        title: "Connect Your Wallet",
        bodyWidget: const _ConnectWalletSlide(),
        image: const Icon(Icons.wallet_rounded, size: 120, color: Colors.black),
        decoration: const PageDecoration(
          titleTextStyle: headingTextStyle,
          contentMargin:
              EdgeInsets.zero, // Remove default padding for custom widget
          fullScreen: false,
        ),
      ),
    ];

    return SafeArea(
      child: IntroductionScreen(
        pages: pages,
        showSkipButton: false,
        next: const Text("Next"),
        // ⚠️ Changed done text to be more general
        done: const Text("Continue",
            style:
                TextStyle(fontWeight: FontWeight.w600, fontFamily: "Poppins")),

        // We must handle navigation manually inside the custom widget,
        // but 'onDone' will redirect if the last page is a standard one.
        // Since the last page is a custom widget that handles its own logic,
        // this onDone is effectively unused for the last slide.
        onDone: () {
          // Fallback or for skip button
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ConnectWalletPage()),
          );
        },
        onSkip: () {
          // Skip redirects to the main entry page for authentication
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ConnectWalletPage()),
          );
        },
        dotsDecorator: DotsDecorator(
          size: const Size.square(10.0),
          activeSize: const Size(22.0, 10.0),
          activeColor: Colors.grey,
          color: Colors.black26,
          spacing: const EdgeInsets.symmetric(horizontal: 3.0),
          activeShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25.0),
          ),
        ),
        // ⚠️ Disable the default done button functionality
        // The custom page will handle the submission via a separate button.
        showDoneButton: false,
        // isBottomSafeArea: true,
      ),
    );
  }
}

// Add a global (or pass it via constructor) variable to hold the role
enum UserRole { doctor, patient }

UserRole? selectedRole;

// ----------------------------------------------------------------------
// CHOOSE ROLE SLIDE
// ----------------------------------------------------------------------

class _ChooseRoleSlide extends StatefulWidget {
  const _ChooseRoleSlide();

  @override
  State<_ChooseRoleSlide> createState() => _ChooseRoleSlideState();
}

class _ChooseRoleSlideState extends State<_ChooseRoleSlide> {
  void _selectRole(UserRole role) {
    setState(() {
      selectedRole = role;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          rowButton(
            onPressed: () => _selectRole(UserRole.patient),
            widgets: [
              Text(
                "I am a Patient",
                style: buttonTextStyle,
              ),
            ],
            backgroundColor: selectedRole == UserRole.patient
                ? lightGreenColor
                : Colors.grey.shade300,
            foregroundColor: Colors.black,
            borderRadius: 8,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          const SizedBox(height: 16),
          rowButton(
            onPressed: () => _selectRole(UserRole.doctor),
            widgets: [
              Text(
                "I am a Doctor",
                style: buttonTextStyle,
              ),
            ],
            backgroundColor: selectedRole == UserRole.doctor
                ? lightGreenColor
                : Colors.grey.shade300,
            foregroundColor: Colors.black,
            borderRadius: 8,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// CONNECT WALLET SLIDE
// ----------------------------------------------------------------------

class _ConnectWalletSlide extends StatefulWidget {
  const _ConnectWalletSlide();

  @override
  State<_ConnectWalletSlide> createState() => _ConnectWalletSlideState();
}

class _ConnectWalletSlideState extends State<_ConnectWalletSlide> {
  final TextEditingController _addressController = TextEditingController();
  final WalletAddrService _storageService = WalletAddrService();
  String? _errorMessage;

  bool _isValidHederaAddress(String address) {
    final evmRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');
    return evmRegex.hasMatch(address);
  }

  void _submitAddress() async {
    final address = _addressController.text.trim();

    if (address.isEmpty) {
      setState(() => _errorMessage = "Wallet address cannot be empty.");
      return;
    }
    if (!_isValidHederaAddress(address)) {
      setState(() =>
          _errorMessage = "Invalid Hedera address format. Use 0xa1b2c3...");
      return;
    }

    final success = await _storageService.setAddress(address);
    if (!mounted) return;

    if (success) {
      if (selectedRole == UserRole.patient) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LinkDoctorPage()),
        );
      } else if (selectedRole == UserRole.doctor) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DoctorNfcPage()),
        );
      } else {
        setState(() => _errorMessage = "Please select a role first.");
      }
    } else {
      setState(
          () => _errorMessage = "Failed to save address locally. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          Text(
            "Enter your Hedera Testnet address to get started.",
            textAlign: TextAlign.center,
            style: body2TextStyle.copyWith(color: Colors.black54),
          ),

          const SizedBox(height: 20),

          //
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              hintText: '0xa1b2c3...',
              hintStyle: buttonTextStyle,
              errorText: _errorMessage,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              prefixIcon: const Icon(
                Icons.account_balance_wallet,
                color: Colors.black54,
              ),
            ),
            onChanged: (_) {
              if (_errorMessage != null) {
                setState(() => _errorMessage = null);
              }
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitAddress,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: const Text(
              "Submit and Continue",
              style: buttonTextStyle,
            ),
          ),
        ],
      ),
    );
  }
}
