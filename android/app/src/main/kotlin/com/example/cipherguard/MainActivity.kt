package com.example.cipherguard

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by local_auth on Android.
// DO NOT use FlutterActivity — local_auth needs a FragmentActivity host
// for the BiometricPrompt API.
class MainActivity : FlutterFragmentActivity() {

    private val SETTINGS_CHANNEL = "cipherguard/settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SETTINGS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openSecuritySettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        // Fallback to general settings if security settings unavailable
                        try {
                            startActivity(
                                Intent(Settings.ACTION_SETTINGS).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                            )
                            result.success(null)
                        } catch (e2: Exception) {
                            result.error("UNAVAILABLE", e2.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
