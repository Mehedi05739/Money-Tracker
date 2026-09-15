package com.example.money_tracker

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, not FlutterActivity: the biometric prompt used by
// the app lock is an AndroidX fragment and needs a FragmentActivity host.
// Under a plain FlutterActivity it throws as soon as the user enables the lock.
class MainActivity : FlutterFragmentActivity() {

    private val settingsChannelName = "money_tracker/system_settings"
    private val documentsChannelName = "money_tracker/documents"

    private val createDocumentRequest = 4001
    private val openDocumentRequest = 4002

    /// Held across the document picker, which returns through onActivityResult.
    private var pendingResult: MethodChannel.Result? = null

    /// What to write once the user has chosen where to put it.
    private var pendingContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, settingsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationSettings" ->
                        result.success(openNotificationSettings())
                    "openChannelSettings" -> {
                        val id = call.argument<String>("channelId")
                        result.success(if (id == null) false else openChannelSettings(id))
                    }
                    "openExactAlarmSettings" ->
                        result.success(openExactAlarmSettings())
                    else -> result.notImplemented()
                }
            }

        // Documents the user owns, chosen through the system picker. These live
        // outside the app's own storage, which is the whole point: everything
        // under /data/user/0/<package> is deleted on uninstall, so a backup
        // written there disappears exactly when it is needed.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, documentsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveDocument" -> saveDocument(
                        call.argument<String>("fileName").orEmpty(),
                        call.argument<String>("mimeType") ?: "application/json",
                        call.argument<String>("content").orEmpty(),
                        result,
                    )
                    "openDocument" -> openDocument(
                        call.argument<List<String>>("mimeTypes"),
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    // ------------------------------------------------------------- documents

    private fun saveDocument(
        fileName: String,
        mimeType: String,
        content: String,
        result: MethodChannel.Result,
    ) {
        if (!claim(result)) return
        pendingContent = content
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType(mimeType)
            .putExtra(Intent.EXTRA_TITLE, fileName)
        launchForResult(intent, createDocumentRequest)
    }

    private fun openDocument(mimeTypes: List<String>?, result: MethodChannel.Result) {
        if (!claim(result)) return
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            // A broad type with a specific filter: some providers hand back
            // octet-stream for a .json file, and refusing it would leave the
            // user unable to select their own backup.
            .setType("*/*")
        if (!mimeTypes.isNullOrEmpty()) {
            intent.putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
        }
        launchForResult(intent, openDocumentRequest)
    }

    /// Refuses a second picker while one is open, rather than losing the first
    /// call's result and leaving its Dart future hanging forever.
    private fun claim(result: MethodChannel.Result): Boolean {
        if (pendingResult != null) {
            result.error("busy", "Another file operation is already open", null)
            return false
        }
        pendingResult = result
        return true
    }

    private fun launchForResult(intent: Intent, requestCode: Int) {
        try {
            startActivityForResult(intent, requestCode)
        } catch (error: Exception) {
            finish(null, "unavailable", "No file picker on this device")
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != createDocumentRequest && requestCode != openDocumentRequest) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            // Cancelling is an ordinary outcome, not an error.
            finish(null, null, null)
            return
        }

        try {
            if (requestCode == createDocumentRequest) {
                contentResolver.openOutputStream(uri)?.use { stream ->
                    stream.write(pendingContent.orEmpty().toByteArray())
                } ?: throw IllegalStateException("Could not open the file for writing")
                finish(displayName(uri) ?: uri.lastPathSegment, null, null)
            } else {
                val text = contentResolver.openInputStream(uri)?.use { stream ->
                    stream.readBytes().toString(Charsets.UTF_8)
                } ?: throw IllegalStateException("Could not open the file for reading")
                finish(text, null, null)
            }
        } catch (error: Exception) {
            finish(null, "io", error.message ?: "The file could not be read")
        }
    }

    private fun finish(value: Any?, errorCode: String?, errorMessage: String?) {
        val result = pendingResult
        pendingResult = null
        pendingContent = null
        if (result == null) return
        if (errorCode == null) result.success(value)
        else result.error(errorCode, errorMessage, null)
    }

    private fun displayName(uri: Uri): String? = try {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
        }
    } catch (error: Exception) {
        null
    }

    // -------------------------------------------------------------- settings

    private fun openNotificationSettings(): Boolean = launch(
        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
    )

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

    private fun openExactAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        return launch(
            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                .setData(Uri.parse("package:$packageName"))
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
