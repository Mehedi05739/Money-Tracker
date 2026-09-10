package com.example.money_tracker

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, not FlutterActivity: the biometric prompt used by
// the app lock is an AndroidX fragment and needs a FragmentActivity host.
// Under a plain FlutterActivity it throws as soon as the user enables the lock.
class MainActivity : FlutterFragmentActivity() {

    // A blocked notification channel cannot be re-enabled by an app — only the
    // user can, in system settings. Without a way to get them there, the only
    // honest thing the app could say is "go and find it yourself".
    private val channelName = "money_tracker/system_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationSettings" -> {
                        result.success(openNotificationSettings())
                    }
                    "openChannelSettings" -> {
                        val id = call.argument<String>("channelId")
                        result.success(
                            if (id == null) false else openChannelSettings(id)
                        )
                    }
                    "openExactAlarmSettings" -> {
                        result.success(openExactAlarmSettings())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openNotificationSettings(): Boolean = launch(
        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
    )

    /// Opens the settings for one channel, which is where a blocked channel is
    /// turned back on.
    private fun openChannelSettings(channelId: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return openNotificationSettings()
        }
        return launch(
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                .putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
        ) || openNotificationSettings()
    }

    /// "Alarms & reminders", which Android 14+ withholds from apps targeting
    /// API 34 and later.
    private fun openExactAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        return launch(
            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                .setData(android.net.Uri.parse("package:$packageName"))
        )
    }

    // Some manufacturer builds ship without the screen the intent names, so a
    // failure to launch must not crash the app that only wanted to help.
    private fun launch(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (error: Exception) {
        false
    }
}
