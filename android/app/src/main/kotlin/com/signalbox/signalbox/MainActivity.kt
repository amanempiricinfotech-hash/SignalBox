package com.signalbox.signalbox

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val METHOD_CHANNEL = "com.signalbox/notification_access"
        const val EVENT_CHANNEL = "com.signalbox/notification_stream"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPermissionGranted" -> result.success(isNotificationAccessGranted())
                    "openPermissionSettings" -> {
                        openNotificationAccessSettings()
                        result.success(null)
                    }
                    "isListenerConnected" ->
                        result.success(NotificationStreamHandler.isListenerConnected())
                    "getInstalledApps" ->
                        result.success(InstalledAppsReader.installedApps(this))
                    "getAppLabel" -> {
                        val pkg = call.argument<String>("packageName")
                        if (pkg == null) {
                            result.error("ARG", "packageName is required", null)
                        } else {
                            result.success(InstalledAppsReader.appLabel(this, pkg))
                        }
                    }
                    "getAppIcon" -> {
                        val pkg = call.argument<String>("packageName")
                        if (pkg == null) {
                            result.error("ARG", "packageName is required", null)
                        } else {
                            result.success(InstalledAppsReader.appIcon(this, pkg))
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(NotificationStreamHandler)
    }

    /**
     * Reads the system list of enabled notification listeners and checks
     * whether SignalBox is part of it.
     */
    private fun isNotificationAccessGranted(): Boolean {
        val expected = ComponentName(
            this,
            SignalBoxNotificationListenerService::class.java
        )
        val enabled = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false

        return enabled.split(":")
            .mapNotNull { ComponentName.unflattenFromString(it) }
            .any { it == expected }
    }

    private fun openNotificationAccessSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}
