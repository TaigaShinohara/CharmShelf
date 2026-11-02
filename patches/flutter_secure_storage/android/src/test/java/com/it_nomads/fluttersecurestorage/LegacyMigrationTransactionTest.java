package com.it_nomads.fluttersecurestorage;

import org.junit.Test;

import java.util.HashMap;
import java.util.Map;

import static org.junit.Assert.*;

public class LegacyMigrationTransactionTest {
    private static final class Store implements LegacyMigrationTransaction.Store {
        Map<String, Object> entries;
        int writes;
        int failAfterWrite;
        boolean fail;
        Store(String key, String value) { entries = new HashMap<>(Map.of(key, value)); }
        @Override public Map<String, Object> read() { return new HashMap<>(entries); }
        @Override public void replace(Map<String, Object> replacement) throws Exception {
            writes++;
            if (fail) throw new Exception("synthetic disk failure");
            entries = new HashMap<>(replacement);
            if (failAfterWrite == writes) throw new Exception("synthetic commit false after memory update");
        }
    }

    private static final class Journal implements LegacyMigrationTransaction.Journal {
        LegacyMigrationTransaction.Snapshot snapshot;
        boolean failSave;
        boolean failClear;
        @Override public LegacyMigrationTransaction.Snapshot load() { return snapshot; }
        @Override public void save(LegacyMigrationTransaction.Snapshot value) throws Exception {
            if (failSave) throw new Exception("synthetic journal failure");
            snapshot = value;
        }
        @Override public void clear() throws Exception {
            if (failClear) throw new Exception("synthetic cleanup failure");
            snapshot = null;
        }
    }

    private static final class ProcessDeath extends Error {}

    private static final class Fixture {
        final Store data = new Store("pin_code", "OLD_CIPHERTEXT");
        final Store keys = new Store("wrapped", "OLD_WRAPPED_KEY");
        final Store markers = new Store("algorithm", "OLD_ALGORITHM");
        final Journal journal = new Journal();
        int attempts;
        int failAfterCommit;
        boolean death;

        void run() throws Exception {
            LegacyMigrationTransaction.run(data, keys, markers, journal,
                    new LegacyMigrationTransaction.Migration() {
                        @Override public boolean needed() { return "OLD_ALGORITHM".equals(markers.entries.get("algorithm")); }
                        @Override public void apply() throws Exception {
                            attempts++;
                            // The actual decoder must receive the original source and key
                            // again, even when the previous process had changed both.
                            assertEquals("OLD_CIPHERTEXT", data.entries.get("pin_code"));
                            assertEquals("OLD_WRAPPED_KEY", keys.entries.get("wrapped"));
                            for (int point = 1; point <= 3; point++) {
                                if (point == 1) keys.replace(Map.of("wrapped", "NEW_WRAPPED_KEY"));
                                if (point == 2) data.replace(Map.of("pin_code", "NEW_CIPHERTEXT"));
                                if (point == 3) markers.replace(Map.of("algorithm", "NEW_ALGORITHM"));
                                if (point == failAfterCommit) {
                                    if (death) throw new ProcessDeath();
                                    throw new Exception("synthetic migration failure");
                                }
                            }
                        }
                    });
        }
    }

    @Test public void failedJournalDoesNotChangeOriginalDataOrKey() {
        Fixture f = new Fixture(); f.journal.failSave = true;
        assertThrows(Exception.class, f::run);
        assertEquals(0, f.attempts);
        assertEquals(0, f.data.writes);
        assertEquals(0, f.keys.writes);
        assertEquals(0, f.markers.writes);
    }

    @Test public void eachPartialFailureRestoresCiphertextAndRetriesSuccessfully() throws Exception {
        for (int point = 1; point <= 3; point++) {
            Fixture f = new Fixture(); f.failAfterCommit = point;
            assertThrows(Exception.class, f::run);
            assertEquals("OLD_CIPHERTEXT", f.data.entries.get("pin_code"));
            assertEquals("OLD_WRAPPED_KEY", f.keys.entries.get("wrapped"));
            assertEquals("OLD_ALGORITHM", f.markers.entries.get("algorithm"));
            assertNotNull(f.journal.snapshot);
            f.failAfterCommit = 0; f.run();
            assertEquals("NEW_CIPHERTEXT", f.data.entries.get("pin_code"));
            assertEquals("NEW_ALGORITHM", f.markers.entries.get("algorithm"));
            assertNull(f.journal.snapshot);
        }
    }

    @Test public void restartAfterEachCommitRestoresSourceBeforeDecoding() throws Exception {
        for (int point = 1; point <= 3; point++) {
            Fixture f = new Fixture(); f.failAfterCommit = point; f.death = true;
            assertThrows(ProcessDeath.class, f::run);
            assertNotNull(f.journal.snapshot);
            f.failAfterCommit = 0; f.run();
            assertEquals(2, f.attempts);
            assertEquals("NEW_CIPHERTEXT", f.data.entries.get("pin_code"));
            assertNull(f.journal.snapshot);
        }
    }

    @Test public void failedRestoreKeepsJournalAndBlocksEntryUntilRetry() throws Exception {
        Fixture f = new Fixture(); f.failAfterCommit = 2; f.death = true;
        assertThrows(ProcessDeath.class, f::run);
        f.data.fail = true; f.failAfterCommit = 0;
        assertThrows(Exception.class, f::run);
        assertEquals(1, f.attempts);
        assertNotNull(f.journal.snapshot);
        f.data.fail = false; f.run();
        assertEquals(2, f.attempts);
    }

    @Test public void journalCleanupFailureIsRecoverableAndNeverReportsSuccess() throws Exception {
        Fixture f = new Fixture(); f.journal.failClear = true;
        assertThrows(Exception.class, f::run);
        assertEquals("NEW_CIPHERTEXT", f.data.entries.get("pin_code"));
        assertNotNull(f.journal.snapshot);
        f.journal.failClear = false; f.run();
        assertEquals("NEW_CIPHERTEXT", f.data.entries.get("pin_code"));
    }

    @Test public void failedCommitThatUpdatedMemoryStillRestoresTheOriginalSource() throws Exception {
        Fixture f = new Fixture(); f.data.failAfterWrite = 1;
        assertThrows(Exception.class, f::run);
        assertEquals("OLD_CIPHERTEXT", f.data.entries.get("pin_code"));
        assertEquals("OLD_WRAPPED_KEY", f.keys.entries.get("wrapped"));
        assertNotNull(f.journal.snapshot);
        f.run();
        assertEquals("NEW_CIPHERTEXT", f.data.entries.get("pin_code"));
    }

    @Test public void alreadyCurrentStoreIsUntouched() throws Exception {
        Fixture f = new Fixture(); f.markers.entries.put("algorithm", "NEW_ALGORITHM");
        f.run();
        assertEquals(0, f.attempts);
        assertEquals(0, f.data.writes);
        assertEquals(0, f.keys.writes);
    }
}
