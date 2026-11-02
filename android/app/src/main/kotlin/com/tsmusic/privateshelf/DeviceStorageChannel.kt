package com.tsmusic.privateshelf

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.Environment
import android.os.storage.StorageManager
import android.system.Os
import android.system.OsConstants
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/** Foreground, read-only access to mounted shared volumes. No private-app roots. */
class DeviceStorageChannel(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.tsmusic.privateshelf/device_storage")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val requests = ConcurrentHashMap<String, CancellationSignal>()

    private fun allowed() = if (Build.VERSION.SDK_INT >= 30) Environment.isExternalStorageManager()
        else context.checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED

    private fun roots(): List<File> {
        val manager = context.getSystemService(Context.STORAGE_SERVICE) as StorageManager
        val result = if (Build.VERSION.SDK_INT >= 30) {
            manager.storageVolumes.filter { it.state == Environment.MEDIA_MOUNTED || it.state == Environment.MEDIA_MOUNTED_READ_ONLY }
                .mapNotNull { it.directory }
        } else {
            // getExternalFilesDirs reports mounted volumes, including removable storage.
            context.getExternalFilesDirs(null).filterNotNull().mapNotNull { dir ->
                val path = dir.absolutePath
                val index = path.indexOf("/Android/data/")
                if (index >= 0) File(path.substring(0, index)) else null
            }
        }
        return result.map { it.canonicalFile }.distinctBy { it.path }.filter { it.isDirectory }
    }

    private fun checked(uri: String, volumes: List<File> = roots()): File {
        // Permission is checked before and after each operation. Avoid an
        // AppOps Binder round-trip per entry when listing large directories.
        val parsed = Uri.parse(uri)
        require(parsed.scheme == "file" && parsed.authority.isNullOrEmpty())
        val file = File(requireNotNull(parsed.path)).absoluteFile
        // Do not follow symlinks, including symlinked ancestors.
        require(file.path == file.canonicalPath) { "symlink" }
        val root = volumes.firstOrNull { file == it || file.path.startsWith(it.path + "/") }
            ?: throw SecurityException("outside_shared_storage")
        val relative = file.relativeTo(root).invariantSeparatorsPath
        require(relative != "Android" && !relative.startsWith("Android/")) { "private_app_storage" }
        return file
    }

    private fun entry(file: File): Map<String, Any?> {
        val stat = Os.lstat(file.path)
        val directory = OsConstants.S_ISDIR(stat.st_mode)
        require(directory || OsConstants.S_ISREG(stat.st_mode))
        check(file.canRead())
        val identity = if (directory) "${stat.st_dev}:${stat.st_ino}:dir"
            else "${stat.st_dev}:${stat.st_ino}:${stat.st_ctime}:${file.lastModified()}:${stat.st_size}"
        return mapOf("id" to identity, "uri" to Uri.fromFile(file).toString(), "name" to file.name,
            "directory" to directory, "size" to if (directory) null else stat.st_size,
            "modified" to file.lastModified())
    }

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "status") {
                result.success(mapOf("allowed" to allowed(), "sdk" to Build.VERSION.SDK_INT))
            } else if (call.method == "cancel") {
                requests[call.argument<String>("requestId")]?.cancel()
                result.success(null)
            } else if (call.method in listOf("roots", "stat", "children", "validate", "legacyEmpty")) {
                val id = call.argument<String>("requestId") ?: ""
                val signal = CancellationSignal()
                requests[id] = signal
                scope.launch {
                    try {
                        val value: Any? = withContext(Dispatchers.IO) {
                            check(allowed()) { "permission" }
                            val payload = when (call.method) {
                                "legacyEmpty" -> {
                                    // Inspect only. Never create, modify or delete legacy data.
                                    val primary = Environment.getExternalStorageDirectory().canonicalFile
                                    check(roots().any { it == primary })
                                    val names = primary.list() ?: error("Cannot inspect primary storage")
                                    if (!names.contains("Documents")) true else {
                                        val documents = checked(Uri.fromFile(File(primary, "Documents")).toString())
                                        val children = documents.list() ?: error("Cannot inspect Documents")
                                        if (!children.contains("CharmShelf")) true else {
                                            val legacy = checked(Uri.fromFile(File(documents, "CharmShelf")).toString())
                                            val remaining = legacy.list() ?: error("Cannot inspect legacy data")
                                            remaining.isEmpty()
                                        }
                                    }
                                }
                                "roots" -> roots().map { file ->
                                    val manager = context.getSystemService(Context.STORAGE_SERVICE) as StorageManager
                                    entry(file) + mapOf("name" to (manager.getStorageVolume(file)?.getDescription(context) ?: file.name))
                                }
                                "stat" -> entry(checked(call.argument<String>("uri")!!))
                                "validate" -> {
                                    val entries = call.argument<List<Map<String, String>>>("entries")!!
                                    val volumes = roots()
                                    for (item in entries) {
                                        signal.throwIfCanceled()
                                        check(entry(checked(item["uri"]!!, volumes))["id"] == item["id"]) { "changed" }
                                    }
                                    true
                                }
                                else -> {
                                    val volumes = roots()
                                    val parent = checked(call.argument<String>("uri")!!, volumes)
                                    check(parent.isDirectory)
                                    val files = parent.listFiles() ?: throw IllegalStateException("unreadable")
                                    check(files.size <= 200000) { "too_many_entries" }
                                    val entries = mutableListOf<Map<String, Any?>>()
                                    var skipped = 0
                                    for (file in files) {
                                        signal.throwIfCanceled()
                                        try {
                                            entries.add(entry(checked(Uri.fromFile(file).toString(), volumes)))
                                        } catch (_: Exception) { skipped++ }
                                    }
                                    mapOf("entries" to entries, "skipped" to skipped)
                                }
                            }
                            check(allowed()) { "permission" }
                            payload
                        }
                        result.success(value)
                    } catch (_: Exception) {
                        result.error(if (signal.isCanceled) "cancelled" else if (!allowed()) "permission" else "unavailable",
                            "Could not access device files", null)
                    } finally { requests.remove(id, signal) }
                }
            } else result.notImplemented()
        }
    }

    fun close() {
        requests.values.forEach { it.cancel() }
        requests.clear()
        channel.setMethodCallHandler(null)
        scope.cancel()
    }
}
