package io.alexrintt.sharedstorage.storageaccessframework

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.documentfile.provider.DocumentFile
import com.anggrayudi.storage.extension.isTreeDocumentFile
import com.anggrayudi.storage.file.child
import io.flutter.plugin.common.*
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.alexrintt.sharedstorage.ROOT_CHANNEL
import io.alexrintt.sharedstorage.SharedStoragePlugin
import io.alexrintt.sharedstorage.plugin.*
import io.alexrintt.sharedstorage.storageaccessframework.lib.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.FileNotFoundException
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream

/**
 * Aimed to implement strictly only the APIs already available from the native and original
 * `DocumentFile` API
 *
 * Basically, this is just an adapter of the native `DocumentFile` class to a Flutter Plugin class,
 * without any modifications or abstractions
 */
internal class DocumentFileApi(private val plugin: SharedStoragePlugin) :
  MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener,
  Listenable, ActivityListener, StreamHandler {
  private data class PendingPicker(
    val call: MethodCall,
    val result: MethodChannel.Result,
    val activity: Activity,
    val isTree: Boolean
  )

  private val pendingResults: MutableMap<Int, PendingPicker> = mutableMapOf()
  private var channel: MethodChannel? = null
  private var eventChannel: EventChannel? = null
  private var eventSink: EventChannel.EventSink? = null

  companion object {
    private const val CHANNEL = "documentfile"
    // Never reuse a request code in this process: a canceled activity can deliver
    // its result after another picker (or Flutter engine) has already opened.
    private var nextPickerRequestCode = 0x5300

    @Synchronized
    private fun allocatePickerRequestCode(): Int {
      check(nextPickerRequestCode <= 0xffff) { "Picker request codes exhausted" }
      return nextPickerRequestCode++
    }
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      GET_DOCUMENT_CONTENT -> {
        val uri = Uri.parse(call.argument<String>("uri")!!)

        if (Build.VERSION.SDK_INT >= API_21) {
          CoroutineScope(Dispatchers.IO).launch {
            val content = readDocumentContent(uri)

            launch(Dispatchers.Main) { result.success(content) }
          }
        } else {
          result.notSupported(call.method, API_21)
        }
      }
      OPEN_DOCUMENT -> if (Build.VERSION.SDK_INT >= API_21) {
        openDocument(call, result)
      }
      OPEN_DOCUMENT_TREE -> if (Build.VERSION.SDK_INT >= API_21) {
        openDocumentTree(call, result)
      }
      CREATE_FILE -> if (Build.VERSION.SDK_INT >= API_21) {
        createFile(
          result,
          call.argument<String>("mimeType")!!,
          call.argument<String>("displayName")!!,
          call.argument<String>("directoryUri")!!,
          call.argument<ByteArray>("content")!!
        )
      }
      WRITE_TO_FILE -> writeToFile(
        result,
        call.argument<String>("uri")!!,
        call.argument<ByteArray>("content")!!,
        call.argument<String>("mode")!!
      )
      PERSISTED_URI_PERMISSIONS -> persistedUriPermissions(result)
      RELEASE_PERSISTABLE_URI_PERMISSION -> releasePersistableUriPermission(
        result, call.argument<String?>("uri") as String
      )
      FROM_TREE_URI -> if (Build.VERSION.SDK_INT >= API_21) {
        result.success(
          createDocumentFileMap(
            plugin.context,
            documentFromUri(
              plugin.context, call.argument<String?>("uri") as String
            )
          )
        )
      }
      CAN_WRITE -> if (Build.VERSION.SDK_INT >= API_21) {
        result.success(
          documentFromUri(
            plugin.context, call.argument<String?>("uri") as String
          )?.canWrite()
        )
      }
      CAN_READ -> if (Build.VERSION.SDK_INT >= API_21) {
        val uri = call.argument<String?>("uri") as String

        result.success(documentFromUri(plugin.context, uri)?.canRead())
      }
      LENGTH -> if (Build.VERSION.SDK_INT >= API_21) {
        result.success(
          documentFromUri(
            plugin.context, call.argument<String?>("uri") as String
          )?.length()
        )
      }
      EXISTS -> if (Build.VERSION.SDK_INT >= API_21) {
        result.success(
          documentFromUri(
            plugin.context, call.argument<String?>("uri") as String
          )?.exists()
        )
      }
      DELETE -> if (Build.VERSION.SDK_INT >= API_21) {
        result.success(
          documentFromUri(
            plugin.context, call.argument<String?>("uri") as String
          )?.delete()
        )
      }
      LAST_MODIFIED -> if (Build.VERSION.SDK_INT >= API_21) {
        val document = documentFromUri(
          plugin.context, call.argument<String?>("uri") as String
        )

        result.success(document?.lastModified())
      }
      CREATE_DIRECTORY -> {
        if (Build.VERSION.SDK_INT >= API_21) {
          val uri = call.argument<String?>("uri") as String
          val displayName = call.argument<String?>("displayName") as String

          val createdDirectory =
            documentFromUri(plugin.context, uri)?.createDirectory(displayName)
              ?: return

          result.success(createDocumentFileMap(plugin.context, createdDirectory))
        } else {
          result.notSupported(call.method, API_21)
        }
      }
      FIND_FILE -> {
        if (Build.VERSION.SDK_INT >= API_21) {
          val uri = call.argument<String?>("uri") as String
          val displayName = call.argument<String?>("displayName") as String

          result.success(
            createDocumentFileMap(
              plugin.context,
              documentFromUri(
                plugin.context, uri
              )?.findFile(displayName)
            )
          )
        }
      }
      COPY -> {
        val uri = Uri.parse(call.argument<String>("uri")!!)
        val destination = Uri.parse(call.argument<String>("destination")!!)

        if (Build.VERSION.SDK_INT >= API_21) {
          if (Build.VERSION.SDK_INT >= API_24) {
            DocumentsContract.copyDocument(
              plugin.context.contentResolver, uri, destination
            )
          } else {
            val inputStream = openInputStream(uri)
            val outputStream = openOutputStream(destination)

            outputStream?.let { inputStream?.copyTo(it) }
          }
        } else {
          result.notSupported(
            RENAME_TO,
            API_21,
            mapOf("uri" to "$uri", "destination" to "$destination")
          )
        }
      }
      RENAME_TO -> {
        val uri = call.argument<String?>("uri") as String
        val displayName = call.argument<String?>("displayName") as String

        if (Build.VERSION.SDK_INT >= API_21) {
          documentFromUri(plugin.context, uri)?.apply {
            val success = renameTo(displayName)

            result.success(
              if (success) createDocumentFileMap(
                plugin.context,
                documentFromUri(
                  plugin.context, this.uri
                )!!
              )
              else null
            )
          }
        } else {
          result.notSupported(
            RENAME_TO, API_21, mapOf("uri" to uri, "displayName" to displayName)
          )
        }
      }
      PARENT_FILE -> {
        val uri = call.argument<String>("uri")!!

        if (Build.VERSION.SDK_INT >= API_21) {
          val parent = documentFromUri(plugin.context, uri)?.parentFile

          result.success(if (parent != null) createDocumentFileMap(plugin.context, parent) else null)
        } else {
          result.notSupported(PARENT_FILE, API_21, mapOf("uri" to uri))
        }
      }
      CHILD -> {
        val uri = call.argument<String>("uri")!!
        val path = call.argument<String>("path")!!
        val requiresWriteAccess =
          call.argument<Boolean>("requiresWriteAccess") ?: false

        if (Build.VERSION.SDK_INT >= API_21) {
          val document = documentFromUri(plugin.context, uri)
          val childDocument =
            document?.child(plugin.context, path, requiresWriteAccess)

          result.success(createDocumentFileMap(plugin.context, childDocument))
        } else {
          result.notSupported(CHILD, API_21, mapOf("uri" to uri))
        }
      }
      CANCEL_ALL_REQUESTS -> {
        cancelPickerRequests()
        result.success(true)
      }
      else -> result.notImplemented()
    }
  }

  @RequiresApi(API_21)
  private fun openDocument(call: MethodCall, result: MethodChannel.Result) {
    val initialUri = call.argument<String>("initialUri")
    val grantWritePermission = call.argument<Boolean>("grantWritePermission")!!
    val persistablePermission =
      call.argument<Boolean>("persistablePermission")!!

    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
      addCategory(Intent.CATEGORY_OPENABLE)
      if (persistablePermission) {
        addFlags(
          Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        )
      }

      if (grantWritePermission) {
        addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
      }

      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

      if (initialUri != null && Build.VERSION.SDK_INT >= API_26) {
        putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse(initialUri))
      }

      type = call.argument<String>("mimeType") ?: "*/*"
      putExtra(
        Intent.EXTRA_ALLOW_MULTIPLE, call.argument<Boolean>("multiple") ?: false
      )
    }

    launchPicker(call, result, intent, isTree = false)
  }

  @RequiresApi(API_21)
  private fun openDocumentTree(call: MethodCall, result: MethodChannel.Result) {
    val initialUri = call.argument<String>("initialUri")
    val grantWritePermission = call.argument<Boolean>("grantWritePermission")!!
    val persistablePermission =
      call.argument<Boolean>("persistablePermission")!!

    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
      if (persistablePermission) {
        addFlags(
          Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        )
      }

      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

      if (grantWritePermission) {
        addFlags(
          Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        )
      }

      if (initialUri != null && Build.VERSION.SDK_INT >= API_26) {
        putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse(initialUri))
      }
    }

    launchPicker(call, result, intent, isTree = true)
  }

  private fun launchPicker(
    call: MethodCall,
    result: MethodChannel.Result,
    intent: Intent,
    isTree: Boolean
  ) {
    if (pendingResults.isNotEmpty()) {
      result.error("already_active", "A document picker is already active", null)
      return
    }
    val activity = plugin.binding?.activity
    if (activity == null) {
      result.error("PICKER_UNAVAILABLE", "A foreground activity is required", null)
      return
    }
    var requestCode: Int? = null
    try {
      val allocatedCode = allocatePickerRequestCode()
      requestCode = allocatedCode
      pendingResults[allocatedCode] = PendingPicker(call, result, activity, isTree)
      activity.startActivityForResult(intent, allocatedCode)
    } catch (error: Exception) {
      if (requestCode != null) pendingResults.remove(requestCode)
      result.error("PICKER_UNAVAILABLE", "Could not open the document picker", null)
    }
  }

  private fun cancelPickerRequests() {
    val canceled = pendingResults.toMap()
    // Remove before finishing the activities or invoking Flutter: both may
    // immediately trigger another callback or open a new picker.
    pendingResults.clear()
    for ((requestCode, pending) in canceled) {
      try {
        @Suppress("DEPRECATION")
        pending.activity.finishActivity(requestCode)
      } catch (error: Exception) {
        Log.w(CHANNEL, "Could not close a canceled document picker", error)
      }
      try {
        pending.result.success(null)
      } catch (error: Exception) {
        Log.w(CHANNEL, "Could not complete a canceled document picker", error)
      }
    }
  }

  @RequiresApi(API_21)
  private fun createFile(
    result: MethodChannel.Result,
    mimeType: String,
    displayName: String,
    directory: String,
    content: ByteArray
  ) {
    createFile(Uri.parse(directory), mimeType, displayName, content) {
      result.success(createDocumentFileMap(plugin.context, this))
    }
  }

  @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
  private fun createFile(
    treeUri: Uri,
    mimeType: String,
    displayName: String,
    content: ByteArray,
    block: DocumentFile?.() -> Unit
  ) {
    val createdFile = documentFromUri(plugin.context, treeUri)!!.createFile(
      mimeType, displayName
    )

    createdFile?.uri?.apply {
      plugin.context.contentResolver.openOutputStream(this)?.apply {
        write(content)
        flush()
        close()

        val createdFileDocument =
          documentFromUri(plugin.context, createdFile.uri)

        block(createdFileDocument)
      }
    }
  }

  private fun writeToFile(
    result: MethodChannel.Result, uri: String, content: ByteArray, mode: String
  ) {
    try {
      plugin.context.contentResolver.openOutputStream(Uri.parse(uri), mode)
        ?.apply {
          write(content)
          flush()
          close()

          result.success(true)
        }
    } catch (e: Exception) {
      result.success(false)
    }
  }

  @RequiresApi(API_19)
  private fun persistedUriPermissions(result: MethodChannel.Result) {
    val persistedUriPermissions =
      plugin.context.contentResolver.persistedUriPermissions

    result.success(persistedUriPermissions.map {
      mapOf(
        "isReadPermission" to it.isReadPermission,
        "isWritePermission" to it.isWritePermission,
        "persistedTime" to it.persistedTime,
        "uri" to "${it.uri}",
        "isTreeDocumentFile" to it.uri.isTreeDocumentFile
      )
    }.toList())
  }

  @RequiresApi(API_19)
  private fun releasePersistableUriPermission(
    result: MethodChannel.Result, directoryUri: String
  ) {
    val targetUri = Uri.parse(directoryUri)

    val persistedUriPermissions =
      plugin.context.contentResolver.persistedUriPermissions

    for (persistedUriPermission in persistedUriPermissions) {
      if (persistedUriPermission.uri == targetUri) {
        var flags = 0

        if (persistedUriPermission.isReadPermission) {
          flags = flags or Intent.FLAG_GRANT_READ_URI_PERMISSION
        }

        if (persistedUriPermission.isWritePermission) {
          flags = flags or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        }

        plugin.context.contentResolver.releasePersistableUriPermission(
          targetUri,
          flags
        )
      }
    }

    result.success(null)
  }

  @RequiresApi(API_19)
  override fun onActivityResult(
    requestCode: Int, resultCode: Int, resultIntent: Intent?
  ): Boolean {
    // Claim exactly this session before reading URIs or acquiring grants. Results
    // from a canceled picker must never complete the next picker session.
    val pending = pendingResults.remove(requestCode) ?: return false
    if (resultCode != Activity.RESULT_OK || resultIntent == null) {
      pending.result.success(null)
      return true
    }

    val uriList = if (pending.isTree) {
      resultIntent.data?.let { listOf(it) }
    } else {
      resultIntent.clipData?.let { clip ->
        (0 until clip.itemCount).map { clip.getItemAt(it).uri }
      } ?: resultIntent.data?.let { listOf(it) }
    }
    if (uriList.isNullOrEmpty()) {
      pending.result.success(null)
      return true
    }

    val newlyAcquired = mutableMapOf<Uri, Int>()
    try {
      val uniqueUris = uriList.distinct()
      check(uniqueUris.all { it.scheme == "content" }) { "Unexpected document URI" }
      if (pending.call.argument<Boolean>("persistablePermission") == true) {
        val resolver = plugin.context.contentResolver
        val previousFlags = resolver.persistedUriPermissions.associate { permission ->
          permission.uri to (
            (if (permission.isReadPermission) Intent.FLAG_GRANT_READ_URI_PERMISSION else 0) or
              (if (permission.isWritePermission) Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0)
            )
        }
        val requestedFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
          (if (pending.call.argument<Boolean>("grantWritePermission") == true)
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0)
        val grantedFlags = resultIntent.flags and requestedFlags
        check((grantedFlags and Intent.FLAG_GRANT_READ_URI_PERMISSION) != 0) {
          "The document provider did not grant read access"
        }
        for (uri in uniqueUris) {
          val newFlags = grantedFlags and (previousFlags[uri] ?: 0).inv()
          if (newFlags == 0) continue
          resolver.takePersistableUriPermission(uri, grantedFlags)
          newlyAcquired[uri] = newFlags
        }
      }
      pending.result.success(
        if (pending.isTree) uniqueUris.single().toString()
        else uniqueUris.map { it.toString() }
      )
    } catch (error: Exception) {
      val cleanupFailures = mutableListOf<Map<String, Any>>()
      for ((uri, flags) in newlyAcquired) {
        try {
          // Release only modes added by this session, preserving any existing
          // read/write grant used by a registered folder or another session.
          plugin.context.contentResolver.releasePersistableUriPermission(uri, flags)
        } catch (cleanupError: Exception) {
          cleanupFailures.add(mapOf("uri" to uri.toString(), "flags" to flags))
          Log.w(CHANNEL, "Could not release an incomplete picker grant", cleanupError)
        }
      }
      pending.result.error(
        if (pending.isTree) "TREE_PERMISSION_FAILED" else "DOCUMENT_PERMISSION_FAILED",
        if (pending.isTree) "Could not retain folder access" else "Could not retain document access",
        if (cleanupFailures.isEmpty()) null else mapOf(
          "grantCleanupFailed" to true,
          "unreleasedUriGrants" to cleanupFailures
        )
      )
    }
    return true
  }

  override fun startListening(binaryMessenger: BinaryMessenger) {
    if (channel != null) stopListening()

    channel = MethodChannel(binaryMessenger, "$ROOT_CHANNEL/$CHANNEL")
    channel?.setMethodCallHandler(this)

    eventChannel = EventChannel(binaryMessenger, "$ROOT_CHANNEL/event/$CHANNEL")
    eventChannel?.setStreamHandler(this)
  }

  override fun stopListening() {
    if (channel == null) return

    cancelPickerRequests()
    channel?.setMethodCallHandler(null)
    channel = null

    eventChannel?.setStreamHandler(null)
    eventChannel = null
  }

  override fun startListeningToActivity() {
    plugin.binding?.addActivityResultListener(this)
  }

  override fun stopListeningToActivity() {
    plugin.binding?.removeActivityResultListener(this)
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    val args = arguments as Map<*, *>

    eventSink = events

    when (args["event"]) {
      LIST_FILES -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
        listFilesEvent(eventSink, args)
      }
    }
  }

  /**
   * Read files of a given `uri` and dispatches all files under it through the `eventSink` and
   * closes the stream after the last record
   *
   * Useful to read files under a `uri` with a large set of children
   */
  private fun listFilesEvent(
    eventSink: EventChannel.EventSink?, args: Map<*, *>
  ) {
    if (eventSink == null) return

    val columns = args["columns"] as List<*>
    val uri = Uri.parse(args["uri"] as String)
    val document = DocumentFile.fromTreeUri(plugin.context, uri)

    if (document == null) {
      eventSink.error(
        EXCEPTION_NOT_SUPPORTED,
        "Android SDK must be greater or equal than [Build.VERSION_CODES.N]",
        "Got (Build.VERSION.SDK_INT): ${Build.VERSION.SDK_INT}"
      )
    } else {
      if (!document.canRead()) {
        val error = "You cannot read a URI that you don't have read permissions"

        Log.d("NO PERMISSION!!!", error)

        eventSink.error(
          EXCEPTION_MISSING_PERMISSIONS, error, mapOf("uri" to args["uri"])
        )

        eventSink.endOfStream()
      } else {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
          CoroutineScope(Dispatchers.IO).launch {
            try {
              traverseDirectoryEntries(
                plugin.context.contentResolver,
                rootOnly = true,
                targetUri = document.uri,
                columns = columns.map {
                  parseDocumentFileColumn(parseDocumentFileColumn(it as String)!!)
                }.toTypedArray()
              ) { data, _ ->
                launch(Dispatchers.Main) {
                  eventSink.success(
                    data
                  )
                }
              }
            } finally {
              launch(Dispatchers.Main) { eventSink.endOfStream() }
            }
          }
        }
      }
    }
  }

  /** Alias for `plugin.context.contentResolver.openOutputStream(uri)` */
  private fun openOutputStream(uri: Uri): OutputStream? {
    return plugin.context.contentResolver.openOutputStream(uri)
  }

  /** Alias for `plugin.context.contentResolver.openInputStream(uri)` */
  private fun openInputStream(uri: Uri): InputStream? {
    return plugin.context.contentResolver.openInputStream(uri)
  }

  /** Get a document content as `ByteArray` equivalent to `Uint8List` in Dart */
  @RequiresApi(API_21)
  private fun readDocumentContent(uri: Uri): ByteArray? {
    return try {
      val inputStream = openInputStream(uri)

      val bytes = inputStream?.readBytes()

      inputStream?.close()

      bytes
    } catch (e: FileNotFoundException) {
      null
    } catch (e: IOException) {
      null
    }
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }
}
