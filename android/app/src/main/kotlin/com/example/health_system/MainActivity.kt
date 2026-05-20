package com.example.health_system

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

// Health Connect permission flow requires FlutterFragmentActivity instead
// of FlutterActivity so the underlying registerForActivityResult contract
// works on Android 14+. The base activity behaviour is otherwise
// identical, so the existing critical-alert pipeline is unaffected.
class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CRITICAL_ALERT_CHANNEL =
            "healthguard/emergency/critical_alert"
        private const val ON_CRITICAL_ALERT_LAUNCH_METHOD = "onCriticalAlertLaunch"
        private const val CONSUME_PENDING_CRITICAL_ALERT_METHOD =
            "consumePendingCriticalAlertLaunch"
        private const val SELECT_NOTIFICATION_ACTION = "SELECT_NOTIFICATION"
        private const val PAYLOAD_EXTRA = "payload"
    }

    private var criticalAlertChannel: MethodChannel? = null
    private var pendingCriticalAlertPayload: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureCriticalAlertPayload(intent)
        applyCriticalAlertWindowFlags()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        criticalAlertChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CRITICAL_ALERT_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    CONSUME_PENDING_CRITICAL_ALERT_METHOD -> {
                        result.success(pendingCriticalAlertPayload)
                        pendingCriticalAlertPayload = null
                    }

                    else -> result.notImplemented()
                }
            }
        }

        dispatchPendingCriticalAlertPayload()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureCriticalAlertPayload(intent)
        applyCriticalAlertWindowFlags()
    }

    private fun captureCriticalAlertPayload(intent: Intent?) {
        val payload = extractCriticalAlertPayload(intent) ?: return
        pendingCriticalAlertPayload = payload
        dispatchPendingCriticalAlertPayload()
    }

    private fun dispatchPendingCriticalAlertPayload() {
        val payload = pendingCriticalAlertPayload ?: return
        criticalAlertChannel?.invokeMethod(ON_CRITICAL_ALERT_LAUNCH_METHOD, payload)
    }

    private fun extractCriticalAlertPayload(intent: Intent?): String? {
        if (intent == null || intent.action != SELECT_NOTIFICATION_ACTION) {
            return null
        }

        val payload = intent.getStringExtra(PAYLOAD_EXTRA)?.trim()
        if (payload.isNullOrEmpty()) {
            return null
        }

        return try {
            val json = JSONObject(payload)
            val alertType = json.optString(
                "alertType",
                json.optString("alert_type", ""),
            )
            val riskLevel = json.optString(
                "riskLevel",
                json.optString("risk_level", ""),
            )
            if (alertType.equals("risk_critical", ignoreCase = true) ||
                riskLevel.equals("critical", ignoreCase = true) ||
                alertType.equals("fall_detected", ignoreCase = true) ||
                alertType.equals("fall_detection", ignoreCase = true)
            ) {
                payload
            } else {
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun applyCriticalAlertWindowFlags() {
        if (extractCriticalAlertPayload(intent) == null) {
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }

        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON,
        )
    }
}
