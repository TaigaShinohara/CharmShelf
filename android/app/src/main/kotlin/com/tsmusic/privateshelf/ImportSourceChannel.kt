package com.tsmusic.privateshelf

import android.content.Context
import android.net.Uri
import android.os.CancellationSignal
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentHashMap

/** Read-only browsing. Never enumerates descendants until the user opens them. */
class ImportSourceChannel(context: Context, messenger: BinaryMessenger) {
    private val resolver = context.contentResolver
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val requests = ConcurrentHashMap<String, CancellationSignal>()
    private val channel = MethodChannel(messenger, "com.tsmusic.privateshelf/import_sources")
    private val columns = arrayOf(
        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        DocumentsContract.Document.COLUMN_MIME_TYPE,
        DocumentsContract.Document.COLUMN_SIZE,
    )

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "cancel") {
                requests[call.argument<String>("requestId")]?.cancel()
                result.success(null)
            } else if (call.method == "root" || call.method == "children") {
                val requestId = call.argument<String>("requestId")!!
                val signal = CancellationSignal()
                requests[requestId] = signal
                scope.launch {
                    try {
                        val value = withContext(Dispatchers.IO) {
                            val tree = Uri.parse(call.argument<String>("treeUri")!!)
                            require(tree.scheme == "content" && DocumentsContract.isTreeUri(tree))
                            check(resolver.persistedUriPermissions.any { it.uri == tree && it.isReadPermission }) {
                                "Read permission is no longer available"
                            }
                            val root = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                            if (call.method == "root") {
                                query(root, tree, signal).single().also {
                                    check(it["directory"] == true) { "Not a directory" }
                                }
                            } else {
                                val directory = Uri.parse(call.argument<String>("directoryUri")!!)
                                require(directory.authority == tree.authority &&
                                    DocumentsContract.getTreeDocumentId(directory) == DocumentsContract.getTreeDocumentId(tree))
                                require(directory == root || DocumentsContract.isChildDocument(resolver, root, directory)) {
                                    "Directory is outside the registered source"
                                }
                                val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getDocumentId(directory))
                                query(children, tree, signal)
                            }
                        }
                        result.success(value)
                    } catch (error: Exception) {
                        result.error(if (signal.isCanceled) "cancelled" else "source_unavailable", "Could not read this location", null)
                    } finally {
                        requests.remove(requestId, signal)
                    }
                }
            } else result.notImplemented()
        }
    }

    private fun query(uri: Uri, tree: Uri, signal: CancellationSignal): List<Map<String, Any?>> {
        val entries = mutableListOf<Map<String, Any?>>()
        val seen = HashSet<String>()
        val cursor = resolver.query(uri, columns, null, null, null, signal)
            ?: throw IllegalStateException("Provider did not return a listing")
        cursor.use {
            while (it.moveToNext()) {
                signal.throwIfCanceled()
                check(entries.size < 200000) { "Too many entries" }
                val id = it.getString(0) ?: throw IllegalStateException("Missing document id")
                if (!seen.add(id)) continue
                val name = it.getString(1) ?: throw IllegalStateException("Missing name")
                require(name.isNotEmpty() && name != "." && name != ".." && !name.contains('/') && !name.contains('\\'))
                val mime = it.getString(2)
                entries.add(mapOf(
                    "id" to id,
                    "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, id).toString(),
                    "name" to name,
                    "directory" to (mime == DocumentsContract.Document.MIME_TYPE_DIR),
                    "mimeType" to mime,
                    "size" to if (it.isNull(3)) null else it.getLong(3).takeIf { size -> size >= 0 },
                ))
            }
            // A loading/partial provider result must not be presented as a complete empty folder.
            check(!it.extras.getBoolean(DocumentsContract.EXTRA_LOADING, false)) { "Provider is still loading" }
            check(it.extras.getString(DocumentsContract.EXTRA_ERROR) == null) { "Provider reported an error" }
        }
        return entries
    }

    fun close() {
        requests.values.forEach { it.cancel() }
        requests.clear()
        channel.setMethodCallHandler(null)
        scope.cancel()
    }
}
