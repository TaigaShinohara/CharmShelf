package com.mr.flutter.plugin.filepicker

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Synthetic callbacks only: no picker UI, file providers, grants, or user files. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class PickerCancellationTest {
    class RecordingActivity : Activity() {
        val finished = mutableListOf<Int>()
        override fun finishActivity(requestCode: Int) { finished.add(requestCode) }
    }

    class Result : MethodChannel.Result {
        val successes = mutableListOf<Any?>()
        val errors = mutableListOf<String>()
        override fun success(result: Any?) { successes.add(result) }
        override fun error(code: String, message: String?, details: Any?) { errors.add(code) }
        override fun notImplemented() { fail("Unexpected notImplemented") }
    }

    private lateinit var activity: RecordingActivity

    @Before
    fun setUp() {
        activity = Robolectric.buildActivity(RecordingActivity::class.java).setup().get()
        LostDataStore.cancelRequest(activity, null).waitingResult?.success(null)
        activity.getSharedPreferences("flutter_file_picker_lost_data", 0).edit().clear().commit()
    }

    private fun start(delegate: FilePickerDelegate, result: Result, save: Boolean = false): Int {
        assertTrue(delegate.setPendingMethodCallResult(result))
        return delegate.allocatePickerRequestCode(save)
    }

    @Test
    fun cancelThenNewPickIgnoresLateSuccessAndCancelFromTheOldActivity() {
        val delegate = FilePickerDelegate(activity)
        val first = Result()
        val oldCode = start(delegate, first)
        delegate.cancelPendingRequest()
        delegate.cancelPendingRequest()
        assertEquals(listOf(null), first.successes)
        assertEquals(listOf(oldCode), activity.finished)

        val second = Result()
        val newCode = start(delegate, second)
        assertNotEquals(oldCode, newCode)
        // A stale success must not enter file processing or persist any grant.
        assertTrue(delegate.onActivityResult(oldCode, Activity.RESULT_OK,
            Intent().setData(Uri.parse("content://synthetic/never-opened"))))
        assertFalse(delegate.onActivityResult(oldCode, Activity.RESULT_CANCELED, null))
        assertTrue(second.successes.isEmpty())
        assertTrue(second.errors.isEmpty())
        assertSame(second, delegate.pendingResult)

        assertTrue(delegate.onActivityResult(newCode, Activity.RESULT_CANCELED, null))
        assertFalse(delegate.onActivityResult(newCode, Activity.RESULT_CANCELED, null))
        assertEquals(listOf(null), second.successes)
        assertNull(delegate.pendingResult)
    }

    @Test
    fun oldIoSuccessOrErrorCannotCompleteTheReplacementRequest() {
        val delegate = FilePickerDelegate(activity)
        val first = Result()
        start(delegate, first)
        val oldGeneration = delegate.requestGeneration
        delegate.cancelPendingRequest()
        val second = Result()
        start(delegate, second)
        delegate.finishWithSuccess("stale path", oldGeneration)
        delegate.finishWithError("stale error", "synthetic", oldGeneration)
        assertTrue(second.successes.isEmpty())
        assertTrue(second.errors.isEmpty())
        assertSame(second, delegate.pendingResult)
        delegate.cancelPendingRequest()
    }

    @Test
    fun unrelatedActivityResultDoesNotCompleteOrFailAnActiveRequest() {
        val delegate = FilePickerDelegate(activity)
        val result = Result()
        start(delegate, result)
        assertFalse(delegate.onActivityResult(-123, Activity.RESULT_OK, Intent()))
        assertTrue(result.successes.isEmpty())
        assertTrue(result.errors.isEmpty())
        delegate.cancelPendingRequest()
    }

    @Test
    fun completionClearsStateBeforeReentrantNextPickAndDeliversOnlyOnce() {
        val delegate = FilePickerDelegate(activity)
        val replacement = Result()
        var completions = 0
        val first = object : MethodChannel.Result {
            override fun success(result: Any?) {
                completions++
                assertNull(delegate.pendingResult)
                start(delegate, replacement)
            }
            override fun error(code: String, message: String?, details: Any?) { fail(code) }
            override fun notImplemented() { fail("Unexpected notImplemented") }
        }
        assertTrue(delegate.setPendingMethodCallResult(first))
        delegate.allocatePickerRequestCode()
        val generation = delegate.requestGeneration
        delegate.finishWithSuccess("synthetic result", generation)
        delegate.finishWithSuccess("duplicate", generation)
        delegate.finishWithError("duplicate", null, generation)
        assertEquals(1, completions)
        assertSame(replacement, delegate.pendingResult)
        delegate.cancelPendingRequest()
    }

    @Test
    fun saveCancellationAndLateOldSaveResultDoNotWriteAnOutput() {
        val delegate = FilePickerDelegate(activity)
        val first = Result()
        val oldCode = start(delegate, first, save = true)
        delegate.cancelPendingRequest()
        val next = Result()
        val newCode = start(delegate, next, save = true)
        assertTrue(delegate.onActivityResult(oldCode, Activity.RESULT_OK,
            Intent().setData(Uri.parse("content://synthetic/never-written"))))
        assertTrue(next.successes.isEmpty())
        assertTrue(delegate.onActivityResult(newCode, Activity.RESULT_CANCELED, null))
        assertEquals(listOf(null), first.successes)
        assertEquals(listOf(null), next.successes)
    }

    @Test
    fun lostRequestRestoresOnlyItsSavedRequestCodeAndDoesNotRestoreTwice() {
        val original = FilePickerDelegate(activity)
        val code = start(original, Result())
        LostDataStore.saveRequest(activity, LostDataStore.PendingRequest("*/*", 0, null, code))
        val recreated = FilePickerDelegate(activity)
        assertFalse(recreated.onActivityResult(-123, Activity.RESULT_CANCELED, null))
        assertTrue(recreated.onActivityResult(code, Activity.RESULT_CANCELED, null))
        assertFalse(LostDataStore.isRestoring)
        assertFalse(recreated.onActivityResult(code, Activity.RESULT_CANCELED, null))
        val lost = Result()
        LostDataStore.retrieve(activity, lost)
        assertEquals(listOf(null), lost.successes)
    }

    @Test
    fun cancelBeforeLostResultRestorePersistsATombstoneAndRejectsLateSuccess() {
        // The saved code does not exist in this process's allocator, as after
        // Android has killed the original process while its picker remained open.
        val oldCode = 0x1234
        LostDataStore.saveRequest(activity, LostDataStore.PendingRequest("*/*", 0, null, oldCode))
        val recreated = FilePickerDelegate(activity)
        val grantsBefore = activity.contentResolver.persistedUriPermissions.toList()
        recreated.cancelPendingRequest()
        recreated.cancelPendingRequest()
        assertNull(LostDataStore.pendingRequestCode(activity))
        assertTrue(oldCode in LostDataStore.cancelledRequestCodes(activity))
        assertEquals(listOf(oldCode), activity.finished)

        val next = Result()
        val newCode = start(recreated, next)
        assertNotEquals(oldCode, newCode)
        assertTrue(recreated.onActivityResult(oldCode, Activity.RESULT_OK,
            Intent().setData(Uri.parse("content://synthetic/cancelled-before-restore"))))
        assertFalse(recreated.onActivityResult(oldCode, Activity.RESULT_OK, Intent()))
        assertFalse(oldCode in LostDataStore.cancelledRequestCodes(activity))
        assertSame(next, recreated.pendingResult)
        assertTrue(next.successes.isEmpty())
        assertTrue(next.errors.isEmpty())
        assertFalse(LostDataStore.isRestoring)
        assertEquals(grantsBefore, activity.contentResolver.persistedUriPermissions)
        assertTrue(recreated.onActivityResult(newCode, Activity.RESULT_CANCELED, null))
        assertEquals(listOf(null), next.successes)
    }

    @Test
    fun recreatedDelegateCancelsOldRestoreAndReentrantRetrievalCanStartANewPick() {
        val oldCode = 0x2345
        LostDataStore.saveRequest(activity, LostDataStore.PendingRequest("*/*", 0, null, oldCode))
        val oldDelegate = FilePickerDelegate(activity)
        // Enter the real restore state without launching provider/coroutine IO.
        val restore = FilePickerDelegate::class.java.getDeclaredMethod(
            "restoreLostRequest", Int::class.javaPrimitiveType)
        restore.isAccessible = true
        assertEquals(true, restore.invoke(oldDelegate, oldCode))
        val oldGeneration = oldDelegate.requestGeneration
        assertTrue(oldDelegate.isCurrentRequest(oldGeneration))

        val recreated = FilePickerDelegate(activity)
        val next = Result()
        var retrievalCompletions = 0
        var newCode = -1
        LostDataStore.retrieve(activity, object : MethodChannel.Result {
            override fun success(result: Any?) {
                retrievalCompletions++
                assertNull(result)
                assertFalse(LostDataStore.isRestoring)
                newCode = start(recreated, next)
                LostDataStore.saveRequest(activity,
                    LostDataStore.PendingRequest("image/*", 80, null, newCode))
            }
            override fun error(code: String, message: String?, details: Any?) { fail(code) }
            override fun notImplemented() { fail("Unexpected notImplemented") }
        })
        assertEquals(0, retrievalCompletions)
        recreated.cancelPendingRequest()
        assertEquals(1, retrievalCompletions)
        assertNotEquals(oldCode, newCode)
        assertEquals(listOf(oldCode), activity.finished)
        assertFalse(oldDelegate.isCurrentRequest(oldGeneration))
        val metadata = activity.getSharedPreferences("flutter_file_picker_lost_data", 0)
            .getString("pending_request", null)
        oldDelegate.finishWithSuccess(emptyList<FileInfo>(), oldGeneration)
        oldDelegate.finishWithError("stale", "old IO completion", oldGeneration)
        assertEquals(metadata, activity.getSharedPreferences("flutter_file_picker_lost_data", 0)
            .getString("pending_request", null))
        assertEquals(newCode, LostDataStore.pendingRequestCode(activity))
        assertSame(next, recreated.pendingResult)
        assertTrue(next.successes.isEmpty())
        assertTrue(next.errors.isEmpty())
        recreated.cancelPendingRequest()
        assertEquals(listOf(null), next.successes)
        assertEquals(1, retrievalCompletions)
    }

    @Test
    fun obsoleteRestoreTokenCannotPublishClearMetadataOrFinishANewerRestore() {
        val oldCode = 0x3456
        LostDataStore.saveRequest(activity, LostDataStore.PendingRequest("*/*", 0, null, oldCode))
        val oldRestore = requireNotNull(LostDataStore.beginRestore(activity, oldCode))
        assertTrue(LostDataStore.isCurrentRestore(oldRestore.token))
        assertNull(LostDataStore.cancelRequest(activity, oldCode).persistenceFailure)
        val newCode = 0x3457
        LostDataStore.saveRequest(activity, LostDataStore.PendingRequest("image/*", 80, null, newCode))
        val newRestore = requireNotNull(LostDataStore.beginRestore(activity, newCode))
        assertNotEquals(oldRestore.token, newRestore.token)
        val waiting = Result()
        LostDataStore.retrieve(activity, waiting)
        // These calls bypass the delegate's early check to cover the publish
        // gate itself, including cancel racing between an IO check and publish.
        LostDataStore.finishRestore(activity, emptyList(), oldRestore.token)
        LostDataStore.finishRestoreWithError(activity, "stale", null, oldRestore.token)
        assertTrue(LostDataStore.isCurrentRestore(newRestore.token))
        assertEquals(newCode, LostDataStore.pendingRequestCode(activity))
        assertTrue(waiting.successes.isEmpty())
        LostDataStore.finishRestore(activity, null, newRestore.token)
        assertEquals(listOf(null), waiting.successes)
        assertFalse(LostDataStore.isRestoring)
        assertNull(LostDataStore.pendingRequestCode(activity))
        val retrieved = Result()
        LostDataStore.retrieve(activity, retrieved)
        assertEquals(listOf(null), retrieved.successes)
    }

    @Test
    fun restorationPersistenceFailureStillInvalidatesOldIoAndCompletesRetrieval() {
        val oldCode = 0x4567
        LostDataStore.saveRequest(activity, LostDataStore.PendingRequest("*/*", 0, null, oldCode))
        val restored = requireNotNull(LostDataStore.beginRestore(activity, oldCode))
        val waiting = Result()
        LostDataStore.retrieve(activity, waiting)
        val recreated = FilePickerDelegate(activity, persistCancellation = { _, _ ->
            throw IllegalStateException("synthetic cancellation commit failure")
        })
        try {
            recreated.cancelPendingRequest()
            fail("Cancellation persistence failure must be reported")
        } catch (failure: IllegalStateException) {
            assertEquals("synthetic cancellation commit failure", failure.message)
        }
        assertEquals(listOf(null), waiting.successes)
        assertFalse(LostDataStore.isCurrentRestore(restored.token))
        assertFalse(LostDataStore.isRestoring)
        val next = Result()
        val newCode = start(recreated, next)
        LostDataStore.saveRequest(activity, LostDataStore.PendingRequest("image/*", 80, null, newCode))
        LostDataStore.finishRestoreWithError(activity, "stale", null, restored.token)
        assertEquals(newCode, LostDataStore.pendingRequestCode(activity))
        assertSame(next, recreated.pendingResult)
        assertTrue(next.errors.isEmpty())
        assertTrue(recreated.onActivityResult(newCode, Activity.RESULT_CANCELED, null))
        assertEquals(listOf(null), next.successes)
    }

    @Test
    fun persistenceFailureBeforeOrAfterMemoryUpdateNeverStrandsThePendingCall() {
        for (memoryUpdated in listOf(false, true)) {
            val delegate = FilePickerDelegate(activity, persistCancellation = { context, code ->
                if (memoryUpdated) {
                    context.getSharedPreferences("flutter_file_picker_lost_data", 0).edit()
                        .remove("pending_request")
                        .putStringSet("cancelled_request_codes", setOf(code.toString())).apply()
                }
                throw IllegalStateException("synthetic cancellation commit failure")
            })
            val first = Result()
            val oldCode = start(delegate, first)
            LostDataStore.saveRequest(activity, LostDataStore.PendingRequest("*/*", 0, null, oldCode))
            try {
                delegate.cancelPendingRequest()
                fail("Cancellation persistence failure must be reported")
            } catch (failure: IllegalStateException) {
                assertEquals("synthetic cancellation commit failure", failure.message)
            }
            assertNull(delegate.pendingResult)
            assertEquals(listOf(null), first.successes)
            assertEquals(oldCode, activity.finished.last())
            val next = Result()
            val newCode = start(delegate, next)
            assertTrue(delegate.onActivityResult(oldCode, Activity.RESULT_OK,
                Intent().setData(Uri.parse("content://synthetic/stale-after-commit-failure"))))
            assertSame(next, delegate.pendingResult)
            assertTrue(next.successes.isEmpty())
            assertTrue(next.errors.isEmpty())
            assertTrue(delegate.onActivityResult(newCode, Activity.RESULT_CANCELED, null))
            assertEquals(listOf(null), next.successes)
        }
    }

    @Test
    fun cancellationPreservesUnrelatedPreferencesAndExistingPersistedGrantState() {
        val preferences = activity.getSharedPreferences("synthetic-provider-state", 0)
        preferences.edit().putString("existingGrant", "content://synthetic/retained")
            .putString("originalFile", "unchanged synthetic contents").commit()
        val before = HashMap(preferences.all)
        val retained = Uri.parse("content://synthetic/retained")
        activity.contentResolver.takePersistableUriPermission(retained, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        val grantsBefore = activity.contentResolver.persistedUriPermissions.map {
            Triple(it.uri, it.isReadPermission, it.isWritePermission)
        }
        assertEquals(listOf(Triple(retained, true, false)), grantsBefore)
        val delegate = FilePickerDelegate(activity)
        val result = Result()
        val code = start(delegate, result)
        delegate.cancelPendingRequest()
        assertTrue(delegate.onActivityResult(code, Activity.RESULT_OK,
            Intent().setData(Uri.parse("content://synthetic/not-granted"))))
        assertEquals(before, preferences.all)
        assertEquals(grantsBefore, activity.contentResolver.persistedUriPermissions.map {
            Triple(it.uri, it.isReadPermission, it.isWritePermission)
        })
        assertEquals(listOf(null), result.successes)
    }
}
