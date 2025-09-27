package com.example.app_frontend

import android.content.Context
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.NfcManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "doctor_nfc_verification/nfc"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNFCEnabled" -> {
                    val nfcManager = getSystemService(Context.NFC_SERVICE) as NfcManager
                    val nfcAdapter = nfcManager.defaultAdapter
                    result.success(nfcAdapter?.isEnabled == true)
                }
                "openNFCSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getInitialLink" -> {
                    result.success(getInitialLink())
                }
                else -> result.notImplemented()
            }
        }
    }

    // Handle new Intents (important for NFC and deep links)
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent) // update the Activity's intent reference
    }

    // Expose initial NFC/deep link intent data
    private fun getInitialLink(): String? {
        return intent?.dataString
    }
}
