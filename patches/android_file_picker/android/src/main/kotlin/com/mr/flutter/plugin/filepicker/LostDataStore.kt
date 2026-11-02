package com.mr.flutter.plugin.filepicker

import android.content.Context
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Persists the in-flight pick request and its result, so a pick survives
 * Android destroying the activity (or the whole process) while the system
 * picker is open.
 *
 * The request options are stored before the picker opens. When a result
 * arrives with no pending request, the delegate restores those options,
 * processes the files as usual and stores the result here instead of dropping
 * it. Dart later reads it once through `retrieveLostData`.
 */
object LostDataStore {
    private const val PREFS_NAME = "flutter_file_picker_lost_data"
    private const val KEY_REQUEST = "pending_request"
    private const val KEY_RESULT = "lost_result"
    private const val KEY_CANCELLED_CODES = "cancelled_request_codes"

    /** The options of a pick request, enough to process its result later. */
    data class PendingRequest(
        val type: String,
        val compressionQuality: Int,
        val androidSafOptions: HashMap<*, *>?,
        val requestCode: Int = FilePickerDelegate.REQUEST_CODE
    )

    data class RestoringRequest(val options: PendingRequest, val token: Long)
    data class Cancellation(
        val waitingResult: MethodChannel.Result?,
        val persistenceFailure: Exception?
    )

    // True while the result of a restored request is being processed, which
    // includes copying the picked files and can take a while.
    private var restoring = false
    private var nextRestoreToken = 0L
    private var restoreToken: Long? = null
    private var restoreRequestCode: Int? = null

    // A retrieveLostData call that arrived while restoring. It is answered
    // once the restored result has been stored.
    private var waitingResult: MethodChannel.Result? = null

    /** Whether the result of a restored request is being processed. */
    val isRestoring: Boolean
        @Synchronized get() = restoring

    fun saveRequest(context: Context, request: PendingRequest) {
        val json = JSONObject()
            .put("type", request.type)
            .put("compressionQuality", request.compressionQuality)
            .put("requestCode", request.requestCode)
            .put("androidSafOptions", request.androidSafOptions?.let { JSONObject(it) })
        prefs(context).edit().putString(KEY_REQUEST, json.toString()).apply()
    }

    /** Keep a newly opened request distinct from a result restored after process death. */
    @Synchronized
    fun pendingRequestCode(context: Context): Int? =
        restoreRequestCode ?: loadRequest(context)?.requestCode

    @Synchronized
    fun isCurrentRestore(token: Long): Boolean = restoring && token == restoreToken

    @Synchronized
    fun cancelledRequestCodes(context: Context): Set<Int> =
        prefs(context).getStringSet(KEY_CANCELLED_CODES, emptySet()).orEmpty()
            .mapNotNull { it.toIntOrNull() }.toSet()

    @Synchronized
    fun cancelRequest(
        context: Context,
        requestCode: Int?,
        persist: (Context, Int?) -> Unit = ::persistCancellation
    ): Cancellation {
        // Invalidate the shared restoration before any old delegate can publish.
        // Defer the Dart callback until the cancelling delegate has cleared itself.
        restoring = false
        restoreToken = null
        restoreRequestCode = null
        val waiter = waitingResult
        waitingResult = null
        var failure: Exception? = null
        try {
            persist(context, requestCode)
        } catch (error: Exception) {
            failure = error
        }
        return Cancellation(waiter, failure)
    }

    fun persistCancellation(context: Context, requestCode: Int?) {
        val editor = prefs(context).edit().remove(KEY_REQUEST)
        if (requestCode != null) {
            val cancelled = cancelledRequestCodes(context) + requestCode
            editor.putStringSet(KEY_CANCELLED_CODES, cancelled.map { it.toString() }.toSet())
        }
        check(editor.commit()) { "Unable to persist picker cancellation" }
    }

    @Synchronized
    fun consumeCancelledRequest(context: Context, requestCode: Int): Boolean {
        val cancelled = cancelledRequestCodes(context)
        if (requestCode !in cancelled) return false
        // Failure only retains an extra tombstone on disk; the stale result is
        // still discarded, and no original file or permission is changed.
        prefs(context).edit().putStringSet(KEY_CANCELLED_CODES,
            (cancelled - requestCode).map { it.toString() }.toSet()).commit()
        return true
    }

    fun clearRequest(context: Context) {
        prefs(context).edit().remove(KEY_REQUEST).apply()
    }

    /**
     * Starts restoring the request whose activity was destroyed while the
     * picker was open, and returns its options, or `null` if there is none.
     */
    @Synchronized
    fun beginRestore(context: Context, requestCode: Int = FilePickerDelegate.REQUEST_CODE): RestoringRequest? {
        if (restoring) return null
        val request = loadRequest(context) ?: return null
        if (request.requestCode != requestCode) return null
        restoring = true
        val token = ++nextRestoreToken
        restoreToken = token
        restoreRequestCode = requestCode
        return RestoringRequest(request, token)
    }

    /**
     * Stores the files of the restored request, or nothing if the pick was
     * cancelled ([files] is `null`), and finishes restoring.
     */
    @Synchronized
    fun finishRestore(context: Context, files: List<FileInfo>?, token: Long) {
        if (!isCurrentRestore(token)) return
        if (files != null) saveFiles(context, files) else clearRequest(context)
        endRestore(context)
    }

    /** Stores the error of the restored request and finishes restoring. */
    @Synchronized
    fun finishRestoreWithError(context: Context, code: String, message: String?, token: Long) {
        if (!isCurrentRestore(token)) return
        saveError(context, code, message)
        endRestore(context)
    }

    /**
     * Answers [result] with the stored outcome of a lost pick, or `null`.
     * Waits if a restored result is still being processed.
     */
    @Synchronized
    fun retrieve(context: Context, result: MethodChannel.Result) {
        if (restoring) {
            waitingResult = result
        } else {
            result.success(takeResult(context))
        }
    }

    private fun endRestore(context: Context) {
        restoring = false
        restoreToken = null
        restoreRequestCode = null
        waitingResult?.let {
            waitingResult = null
            it.success(takeResult(context))
        }
    }

    private fun loadRequest(context: Context): PendingRequest? {
        val raw = prefs(context).getString(KEY_REQUEST, null) ?: return null
        return try {
            val json = JSONObject(raw)
            PendingRequest(
                type = json.getString("type"),
                compressionQuality = json.optInt("compressionQuality", 0),
                androidSafOptions = json.optJSONObject("androidSafOptions")?.let { toMap(it) },
                requestCode = json.optInt("requestCode", FilePickerDelegate.REQUEST_CODE)
            )
        } catch (e: Exception) {
            null
        }
    }

    /** Stores the files of an orphaned pick, replacing any previous one. */
    private fun saveFiles(context: Context, files: List<FileInfo>) {
        val array = JSONArray()
        files.forEach { array.put(JSONObject(it.toMap())) }
        storeResult(context, JSONObject().put("files", array))
    }

    /** Stores the error of an orphaned pick, replacing any previous one. */
    private fun saveError(context: Context, code: String, message: String?) {
        storeResult(
            context,
            JSONObject().put("errorCode", code).put("errorMessage", message)
        )
    }

    /**
     * Returns the stored result as a map for the method channel, or `null`
     * when there is none, and clears it so it is only delivered once.
     */
    private fun takeResult(context: Context): HashMap<String, Any?>? {
        val prefs = prefs(context)
        val raw = prefs.getString(KEY_RESULT, null) ?: return null
        prefs.edit().remove(KEY_RESULT).apply()
        return try {
            toMap(JSONObject(raw))
        } catch (e: Exception) {
            null
        }
    }

    private fun storeResult(context: Context, json: JSONObject) {
        prefs(context).edit()
            .putString(KEY_RESULT, json.toString())
            .remove(KEY_REQUEST)
            .apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun toMap(json: JSONObject): HashMap<String, Any?> {
        val map = HashMap<String, Any?>()
        json.keys().forEach { key -> map[key] = fromJson(json.get(key)) }
        return map
    }

    private fun fromJson(value: Any?): Any? = when (value) {
        JSONObject.NULL -> null
        is JSONObject -> toMap(value)
        is JSONArray -> (0 until value.length()).map { fromJson(value.get(it)) }
        else -> value
    }
}
