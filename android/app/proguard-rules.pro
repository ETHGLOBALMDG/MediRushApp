# NFC related rules
-keep class android.nfc.** { *; }
-keep class * implements android.nfc.tech.** { *; }

# Crypto related rules
-keep class java.security.** { *; }
-keep class javax.crypto.** { *; }

# Flutter NFC Manager plugin rules
-keep class im.nfc.flutter_nfc_kit.** { *; }