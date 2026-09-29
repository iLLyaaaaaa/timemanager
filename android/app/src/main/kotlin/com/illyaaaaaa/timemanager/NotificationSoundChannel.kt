package com.illyaaaaaa.timemanager

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Provides a grantable content URI for a private, already-trimmed alert sound. */
internal class NotificationSoundChannel(
    private val activity: MainActivity,
    messenger: BinaryMessenger,
) {
    init {
        MethodChannel(messenger, "timemanager/notification_sound")
            .setMethodCallHandler { call, result ->
                if (call.method != "contentUriForSound") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val path = call.argument<String>("path")
                        ?: throw IllegalArgumentException("Missing sound")
                    val directory = File(activity.filesDir, "custom_sounds").canonicalFile
                    val file = File(path).canonicalFile
                    if (!file.path.startsWith(directory.path + File.separator) ||
                        !file.isFile || !file.canRead()) {
                        throw IllegalArgumentException("Sound is unavailable")
                    }
                    val uri = FileProvider.getUriForFile(
                        activity,
                        "${activity.packageName}.timer_sounds",
                        file,
                    )
                    var granted = false
                    for (systemPackage in listOf("com.android.systemui", "android")) {
                        try {
                            activity.grantUriPermission(
                                systemPackage,
                                uri,
                                Intent.FLAG_GRANT_READ_URI_PERMISSION,
                            )
                            granted = true
                        } catch (_: Exception) {
                            // System UI package names differ across Android devices.
                        }
                    }
                    if (!granted) throw IllegalStateException("System sound access unavailable")
                    result.success(uri.toString())
                } catch (_: Exception) {
                    result.error("SOUND_UNAVAILABLE", "Custom notification sound unavailable", null)
                }
            }
    }
}
