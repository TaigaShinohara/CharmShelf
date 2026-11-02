package com.mr.flutter.plugin.filepicker

import android.app.Activity
import android.content.Intent
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.mr.flutter.plugin.filepicker.FileUtils.maybeRenameGenericMimeDuplicate
import com.mr.flutter.plugin.filepicker.FileUtils.processFiles
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import java.io.IOException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class FilePickerDelegate(
    val activity: Activity,
    var pendingResult: MethodChannel.Result? = null,
    private val persistCancellation: (Context, Int?) -> Unit = LostDataStore::persistCancellation
) : ActivityResultListener {

    companion object {
        const val TAG = "FilePickerDelegate"
        const val REQUEST_CODE = 0x4F50
        const val SAVE_FILE_CODE = 0x4F51

        private var nextRequestCode = 0x4F52
        private val reservedCodes = mutableSetOf<Int>()
        private val retiredCodes = mutableSetOf<Int>()

        @Synchronized
        private fun reserveCode(savedCode: Int?, cancelledCodes: Set<Int>): Int {
            repeat(0xffff) {
                nextRequestCode = nextRequestCode % 0xffff + 1
                if (nextRequestCode != REQUEST_CODE && nextRequestCode != SAVE_FILE_CODE &&
                    nextRequestCode != savedCode && nextRequestCode !in cancelledCodes &&
                    reservedCodes.add(nextRequestCode)) return nextRequestCode
            }
            throw IllegalStateException("No picker request codes are available")
        }

        @Synchronized
        private fun releaseCode(code: Int) {
            reservedCodes.remove(code)
            retiredCodes.remove(code)
        }

        @Synchronized
        private fun retireCode(code: Int) {
            reservedCodes.add(code)
            retiredCodes.add(code)
        }

        @Synchronized
        private fun consumeRetiredCode(code: Int): Boolean {
            if (!retiredCodes.remove(code)) return false
            reservedCodes.remove(code)
            return true
        }

        @Synchronized
        private fun releaseUnlessRetired(code: Int) {
            if (code !in retiredCodes) reservedCodes.remove(code)
        }

        fun finishWithAlreadyActiveError(result: MethodChannel.Result) {
            result.error("already_active", "File picker is already active", null)
        }
    }

    var isMultipleSelection = false
    var type: String? = null
    var compressionQuality = 0
    var allowedExtensions: ArrayList<String>? = null
    var eventSink: EventSink? = null
    var bytes: ByteArray? = null
    var saveFileName: String? = null
    var saveMimeType: String? = null
    var androidSafOptions: java.util.HashMap<*, *>? = null

    fun setEventHandler(eventSink: EventSink?) {
        this.eventSink = eventSink
    }

    @Volatile
    var requestGeneration: Long = 0
        private set
    private var activeRequestCode: Int? = null
    private var activeRequestIsSave = false
    private var restoringRequest = false
    private var restoreToken: Long? = null

    @Synchronized
    fun allocatePickerRequestCode(save: Boolean = false): Int {
        check(activeRequestCode == null)
        activeRequestIsSave = save
        val context = activity.applicationContext
        return reserveCode(LostDataStore.pendingRequestCode(context),
            LostDataStore.cancelledRequestCodes(context)).also { activeRequestCode = it }
    }

    @Synchronized
    fun isCurrentRequest(generation: Long): Boolean =
        generation == requestGeneration && (pendingResult != null ||
            (restoringRequest && restoreToken?.let(LostDataStore::isCurrentRestore) == true))

    @Synchronized
    fun cancelPendingRequest() {
        val context = activity.applicationContext
        val hasLocalRequest = pendingResult != null || restoringRequest
        val code = activeRequestCode ?: if (!hasLocalRequest)
            LostDataStore.pendingRequestCode(context) else null
        if (!hasLocalRequest && code == null && !LostDataStore.isRestoring) return
        // The tombstone and pending removal share one durable preference commit.
        // A further process death must not resurrect this cancelled picker.
        val cancelled = LostDataStore.cancelRequest(context, code, persistCancellation)
        if (code != null) retireCode(code)
        val result = pendingResult
        clearPendingResult()
        dispatchEventStatus(false)
        try {
            result?.success(null)
        } finally {
            try {
                cancelled.waitingResult?.success(null)
            } finally {
                if (code != null) {
                    @Suppress("DEPRECATION")
                    activity.finishActivity(code)
                }
            }
        }
        // commit(false) may already have changed SharedPreferences in memory.
        // Report failure only after completing and invalidating local callbacks.
        cancelled.persistenceFailure?.let { throw it }
    }

    @Synchronized
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (LostDataStore.consumeCancelledRequest(activity.applicationContext, requestCode)) {
            consumeRetiredCode(requestCode)
            return true
        }
        if (requestCode != activeRequestCode) {
            // A cancelled picker may report after its replacement has opened.
            if (consumeRetiredCode(requestCode)) return true
            if (pendingResult != null || !restoreLostRequest(requestCode)) return false
        }
        val save = activeRequestIsSave
        activeRequestCode = null
        releaseCode(requestCode)
        return if (save) handleSaveFileResult(resultCode, data)
            else handleFilePickerResult(resultCode, data)
    }

    private fun handleSaveFileResult(resultCode: Int, data: Intent?): Boolean {
        return when (resultCode) {
            Activity.RESULT_OK -> saveFile(data?.data)
            Activity.RESULT_CANCELED -> {
                finishWithSuccess(null)
                true
            }

            else -> {
                finishWithError("unknown_activity", "Unexpected picker result code.")
                true
            }
        }
    }

    private fun saveFile(uri: Uri?): Boolean {
        if (uri == null) {
            finishWithError("unknown_path", "The save picker returned no document URI.")
            return true
        }
        val generation = requestGeneration
        val bytesToSave = bytes
        val originalName = saveFileName
        val mimeType = saveMimeType
        dispatchEventStatus(true)
        CoroutineScope(Dispatchers.IO).launch {
            if (!isCurrentRequest(generation)) return@launch
            try {
                val savedUri = FileUtils.writeBytesData(context = activity, uri, bytesToSave) ?: uri
                if (!isCurrentRequest(generation)) return@launch
                val renamedUri = maybeRenameGenericMimeDuplicate(
                    context = activity,
                    uri = savedUri,
                    originalFileName = originalName,
                    mimeType = mimeType
                )
                Handler(Looper.getMainLooper()).post {
                    finishWithSuccess(renamedUri.path, generation)
                }
            } catch (e: IOException) {
                Log.e(TAG, "Error while saving file", e)
                Handler(Looper.getMainLooper()).post {
                    finishWithError("Error while saving file", e.message, generation)
                }
            }
        }
        return true
    }

    private fun handleFilePickerResult(resultCode: Int, data: Intent?): Boolean {
        return when (resultCode) {
            Activity.RESULT_OK -> {
                dispatchEventStatus(true)
                processFiles(activity, data, compressionQuality, type.orEmpty(), androidSafOptions)
                true
            }

            Activity.RESULT_CANCELED -> {
                finishWithSuccess(null)
                true
            }

            else -> {
                finishWithError("unknown_activity", "Unexpected picker result code.")
                true
            }
        }
    }

    /**
     * Restores the options of a request whose activity was destroyed while the
     * picker was open. Returns `false` when there is nothing to restore.
     */
    private fun restoreLostRequest(requestCode: Int): Boolean {
        val restored = LostDataStore.beginRestore(activity.applicationContext, requestCode) ?: return false
        val request = restored.options
        requestGeneration++
        restoringRequest = true
        restoreToken = restored.token
        activeRequestCode = requestCode
        activeRequestIsSave = false
        type = request.type
        compressionQuality = request.compressionQuality
        androidSafOptions = request.androidSafOptions
        return true
    }

    @Synchronized
    fun setPendingMethodCallResult(result: MethodChannel.Result): Boolean {
        return if (pendingResult == null && !LostDataStore.isRestoring) {
            requestGeneration++
            pendingResult = result
            true
        } else {
            false
        }
    }

    @Synchronized
    fun finishWithSuccess(data: Any?, generation: Long = requestGeneration) {
        if (!isCurrentRequest(generation)) return
        dispatchEventStatus(false)
        val context = activity.applicationContext
        if (isLostResult()) {
            val files = (data as? List<*>)?.filterIsInstance<FileInfo>()
            val token = restoreToken ?: return
            clearPendingResult()
            LostDataStore.finishRestore(context, files, token)
            return
        }
        LostDataStore.clearRequest(context)
        val result = pendingResult
        clearPendingResult()
        result?.success(data?.takeIf { it is String }
            ?: (data as? List<*>)?.mapNotNull { (it as? FileInfo)?.toMap() })
    }

    @Synchronized
    fun finishWithError(errorCode: String, errorMessage: String?, generation: Long = requestGeneration) {
        if (!isCurrentRequest(generation)) return
        dispatchEventStatus(false)
        val context = activity.applicationContext
        if (isLostResult()) {
            val token = restoreToken ?: return
            clearPendingResult()
            LostDataStore.finishRestoreWithError(context, errorCode, errorMessage, token)
            return
        }
        LostDataStore.clearRequest(context)
        val result = pendingResult
        clearPendingResult()
        result?.error(errorCode, errorMessage, null)
    }

    private fun dispatchEventStatus(status: Boolean) {
        if (eventSink != null && type != "dir") {
            Handler(Looper.getMainLooper()).post { eventSink?.success(status) }
        }
    }

    /**
     * Whether the result being finished belongs to a restored request, whose
     * outcome goes to LostDataStore instead of a pending method call.
     */
    private fun isLostResult(): Boolean = restoringRequest

    private fun clearPendingResult() {
        activeRequestCode?.let { releaseUnlessRetired(it) }
        activeRequestCode = null
        restoringRequest = false
        restoreToken = null
        requestGeneration++
        pendingResult = null
    }
}
