package com.tsmusic.privateshelf

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.StatFs
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity: AudioServiceFragmentActivity() {
    private val safChannelName = "com.tsmusic.privateshelf/saf"
    private val privacyChannelName = "com.tsmusic.privateshelf/privacy"

    companion object {
        private const val PICKER_NOTIFICATION_CHANNEL_ID = "picker_return"
        private const val PICKER_NOTIFICATION_ID = 9999
        private const val PICKER_NOTIFICATION_PERMISSION_REQUEST_CODE = 4101
    }

    private var deviceStorageChannel: DeviceStorageChannel? = null
    private var importSourceChannel: ImportSourceChannel? = null
    private var legacyDataChannel: LegacyDataChannel? = null
    private var safMethodChannel: MethodChannel? = null
    private var privacyMethodChannel: MethodChannel? = null
    private var pendingPickerTitle: String? = null
    private var pendingPickerBody: String? = null

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        deviceStorageChannel?.close()
        deviceStorageChannel = null
        importSourceChannel?.close()
        importSourceChannel = null
        legacyDataChannel?.close()
        legacyDataChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Dart設定を読み込む前の最初のフレームから安全側で保護する。
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        deviceStorageChannel?.close()
        deviceStorageChannel = DeviceStorageChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        importSourceChannel?.close()
        importSourceChannel = ImportSourceChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        legacyDataChannel?.close()
        legacyDataChannel = LegacyDataChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)

        // ピッカー用の通知チャネルを作成
        createPickerNotificationChannel()

        safMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, safChannelName)
        safMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "copyUriToFile" -> {
                    val uriStr = call.argument<String>("uri")
                    val destPath = call.argument<String>("destPath")
                    val maxBytes = call.argument<Number>("maxBytes")?.toLong()
                    
                    if (uriStr == null || destPath == null || maxBytes == null || maxBytes < 0) {
                        result.error("INVALID_ARGS", "uri, destPath, or maxBytes is invalid", null)
                        return@setMethodCallHandler
                    }

                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val uri = Uri.parse(uriStr)
                            val destFile = File(destPath)
                            
                            val inputStream = applicationContext.contentResolver.openInputStream(uri)
                            if (inputStream == null) {
                                withContext(Dispatchers.Main) {
                                    result.success(false)
                                }
                                return@launch
                            }

                            inputStream.use {
                                FileOutputStream(destFile).use { outputStream ->
                                    copyWithinLimit(it, outputStream, maxBytes)
                                    outputStream.flush()
                                }
                            }
                            
                            withContext(Dispatchers.Main) {
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("COPY_FAILED", e.message, null)
                            }
                        }
                    }
                }
                "copyFileToUri" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val uriStr = call.argument<String>("uri")

                    if (sourcePath == null || uriStr == null) {
                        result.error("INVALID_ARGS", "sourcePath or uri is null", null)
                        return@setMethodCallHandler
                    }

                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val sourceFile = File(sourcePath)
                            if (!sourceFile.isFile) {
                                withContext(Dispatchers.Main) { result.success(false) }
                                return@launch
                            }
                            val targetUri = Uri.parse(uriStr)
                            val outputStream = applicationContext.contentResolver
                                .openOutputStream(targetUri, "wt")
                            if (outputStream == null) {
                                withContext(Dispatchers.Main) { result.success(false) }
                                return@launch
                            }

                            FileInputStream(sourceFile).use { input ->
                                outputStream.use { output ->
                                    input.copyTo(output, 64 * 1024)
                                    output.flush()
                                }
                            }
                            withContext(Dispatchers.Main) { result.success(true) }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("COPY_FAILED", e.message, null)
                            }
                        }
                    }
                }
                "showPickerNotification" -> {
                    val title = call.argument<String>("title") ?: "CharmShelf に戻る"
                    val body = call.argument<String>("body") ?: "タップしてアプリに戻ります"
                    showPickerNotification(title, body)
                    result.success(true)
                }
                "cancelPickerNotification" -> {
                    cancelPickerNotification()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        privacyMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, privacyChannelName)
        privacyMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setMultitaskSecure" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(true)
                    }
                }
                "getAvailableStorageBytes" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "path is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(StatFs(path).availableBytes)
                    } catch (e: Exception) {
                        result.error("STORAGE_CAPACITY_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // 通知からの復帰（MainActivityが再利用される場合）を検知
        if (intent.flags and Intent.FLAG_ACTIVITY_REORDER_TO_FRONT != 0) {
            safMethodChannel?.invokeMethod("onReturnFromNotification", null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PICKER_NOTIFICATION_PERMISSION_REQUEST_CODE) return
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            pendingPickerTitle = null
            pendingPickerBody = null
            return
        }
        val title = pendingPickerTitle
        val body = pendingPickerBody
        pendingPickerTitle = null
        pendingPickerBody = null
        if (title != null && body != null) {
            showPickerNotification(title, body)
        }
    }

    // ─── ピッカー用通知 ───

    private fun createPickerNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                PICKER_NOTIFICATION_CHANNEL_ID,
                "インポート復帰",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "ファイルピッカーからアプリに戻るための通知"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun showPickerNotification(title: String, body: String) {
        createPickerNotificationChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingPickerTitle = title
            pendingPickerBody = body
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                PICKER_NOTIFICATION_PERMISSION_REQUEST_CODE
            )
            return
        }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!manager.areNotificationsEnabled()) {
            return
        }

        // タップ時に MainActivity を前面に戻す Intent
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, PICKER_NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_revert)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .setOngoing(true)  // スワイプで消せないようにする
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        manager.notify(PICKER_NOTIFICATION_ID, notification)
    }

    private fun cancelPickerNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(PICKER_NOTIFICATION_ID)
    }
}
