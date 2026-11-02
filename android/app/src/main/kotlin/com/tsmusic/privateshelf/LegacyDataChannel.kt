package com.tsmusic.privateshelf

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.security.MessageDigest
import java.util.concurrent.Executors

/** Strict, local-provider-only access for the one-time legacy migration. */
internal class LegacyDataChannel(private val context: Context, messenger: BinaryMessenger) {
    private val executor = Executors.newSingleThreadExecutor()
    private val channel = MethodChannel(messenger, "com.tsmusic.privateshelf/legacy")
    private val resolver get() = context.contentResolver
    private val authority = "com.android.externalstorage.documents"
    private val rootId = "primary:Documents/CharmShelf"
    private val maxBytes = 100L * 1024 * 1024 * 1024
    init {
        channel.setMethodCallHandler { call, result ->
            executor.execute {
                try {
                    val tree = Uri.parse(call.argument<String>("tree") ?: error("Missing tree"))
                    require(tree.authority == authority && tree.scheme == "content")
                    require(DocumentsContract.getTreeDocumentId(tree) == "primary:Documents")
                    val value: Any? = when (call.method) {
                        "scan" -> scan(tree)
                        "copy" -> {
                            val relative = call.argument<String>("path")!!
                            val expected = call.argument<String>("hash")!!
                            val target = File(call.argument<String>("destination")!!).canonicalFile
                            // Flutter's application documents directory is below dataDir.
                            require(target.path.startsWith(File(context.applicationInfo.dataDir).canonicalPath + "/"))
                            target.parentFile!!.mkdirs()
                            val partial = File(target.path + ".part")
                            try {
                                val digest = MessageDigest.getInstance("SHA-256")
                                var count = 0L
                                resolver.openInputStream(document(tree, relative))!!.use { input ->
                                    partial.outputStream().use { output ->
                                        val buffer = ByteArray(65536)
                                        while (true) {
                                            val n = input.read(buffer)
                                            if (n < 0) break
                                            count += n
                                            require(count <= maxBytes)
                                            digest.update(buffer, 0, n)
                                            output.write(buffer, 0, n)
                                        }
                                        output.fd.sync()
                                    }
                                }
                                check(hex(digest.digest()) == expected) { "Source changed" }
                                check(partial.renameTo(target)) { "Cannot commit copy" }
                            } finally { partial.delete() }
                            true
                        }
                        "deleteFile" -> {
                            val uri = document(tree, call.argument<String>("path")!!)
                            val expected = call.argument<String>("hash")!!
                            check(hash(uri) == expected) { "Source changed" }
                            check(DocumentsContract.deleteDocument(resolver, uri)) { "Delete failed" }
                            true
                        }
                        else -> error("Unknown legacy operation")
                    }
                    Handler(Looper.getMainLooper()).post { result.success(value) }
                } catch (e: Exception) {
                    Handler(Looper.getMainLooper()).post {
                        result.error("LEGACY_ACCESS", e.message, null)
                    }
                }
            }
        }
    }
    fun close() { channel.setMethodCallHandler(null); executor.shutdown() }

    private fun document(tree: Uri, relative: String): Uri {
        require(relative.isNotEmpty() && relative.split('/').all {
            it.isNotEmpty() && it != "." && it != ".." && !it.contains('\\')
        })
        require(relative.split('/').size <= 64)
        return DocumentsContract.buildDocumentUriUsingTree(tree, "$rootId/$relative")
    }
    private data class Entry(val id: String, val name: String, val directory: Boolean, val size: Long)
    private fun children(tree: Uri, id: String): List<Entry> {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, id)
        val columns = arrayOf("document_id", "_display_name", "mime_type", "_size")
        val cursor = resolver.query(uri, columns, null, null, null)
            ?: throw IOException("Cannot list folder")
        return cursor.use {
            val entries = mutableListOf<Entry>()
            while (it.moveToNext()) {
                val name = it.getString(1) ?: throw IOException("Missing file name")
                require(name.isNotEmpty() && name != "." && name != ".." && !name.contains('/') && !name.contains('\\'))
                val childId = it.getString(0)
                require(childId == "$id/$name") { "Unexpected document identity" }
                entries.add(Entry(childId, name, it.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR, it.getLong(3)))
                require(entries.size <= 200000)
            }
            check(entries.map { entry -> entry.name }.toSet().size == entries.size)
            entries
        }
    }
    private fun scan(tree: Uri): List<Map<String, Any>> {
        val root = children(tree, "primary:Documents").singleOrNull { it.name == "CharmShelf" }
            ?: return emptyList()
        check(root.directory)
        val output = mutableListOf<Map<String, Any>>()
        var total = 0L
        fun walk(id: String, prefix: String, depth: Int) {
            require(depth <= 64)
            for (entry in children(tree, id)) {
                val relative = prefix + entry.name
                require(output.size < 200000)
                if (entry.directory) {
                    output.add(mapOf("path" to relative, "directory" to true, "size" to 0L, "hash" to ""))
                    walk(entry.id, "$relative/", depth + 1)
                } else {
                    require(entry.size >= 0)
                    total += entry.size
                    require(total <= maxBytes)
                    output.add(mapOf("path" to relative, "directory" to false, "size" to entry.size,
                        "hash" to hash(document(tree, relative))))
                }
            }
        }
        walk(root.id, "", 0)
        return output
    }
    private fun hash(uri: Uri): String {
        val digest = MessageDigest.getInstance("SHA-256")
        var count = 0L
        (resolver.openInputStream(uri) ?: throw IOException("Cannot read file")).use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                count += n
                require(count <= maxBytes)
                digest.update(buffer, 0, n)
            }
        }
        return hex(digest.digest())
    }
    private fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it) }
}
