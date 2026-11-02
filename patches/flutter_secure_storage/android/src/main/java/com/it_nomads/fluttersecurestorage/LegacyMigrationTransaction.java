package com.it_nomads.fluttersecurestorage;

import java.util.HashMap;
import java.util.Map;

/** Transaction boundary for the app's read-only legacy decoder and v11 writer. */
final class LegacyMigrationTransaction {
    interface Store {
        Map<String, Object> read();
        /** Must throw unless the complete replacement has been durably committed. */
        void replace(Map<String, Object> entries) throws Exception;
    }

    interface Journal {
        Snapshot load() throws Exception;
        /** Snapshots contain original ciphertext and algorithm markers, never plaintext. */
        void save(Snapshot snapshot) throws Exception;
        void clear() throws Exception;
    }

    interface Migration {
        boolean needed() throws Exception;
        /** Decode every value before changing data; verify every new ciphertext. */
        void apply() throws Exception;
    }

    static final class Snapshot {
        final Map<String, Object> data;
        final Map<String, Object> keys;
        final Map<String, Object> markers;

        Snapshot(Store data, Store keys, Store markers) {
            this(data.read(), keys.read(), markers.read());
        }

        Snapshot(Map<String, Object> data, Map<String, Object> keys,
                 Map<String, Object> markers) {
            this.data = new HashMap<>(data);
            this.keys = new HashMap<>(keys);
            this.markers = new HashMap<>(markers);
        }
    }

    static void run(Store data, Store keys, Store markers, Journal journal,
                    Migration migration) throws Exception {
        Snapshot snapshot = journal.load();
        if (snapshot != null) {
            // The previous process may have stopped between the data and marker commits.
            // Restore the original ciphertext AND wrapped key before attempting to read it.
            restore(snapshot, data, keys, markers);
        }
        if (!migration.needed()) {
            if (snapshot != null) journal.clear();
            return;
        }
        if (snapshot == null) {
            snapshot = new Snapshot(data, keys, markers);
            journal.save(snapshot);
        }
        try {
            migration.apply();
        } catch (Exception failure) {
            // Keep the journal even after a successful restore: a subsequent call retries
            // the migration, while a failed restore can itself be retried after restart.
            try {
                restore(snapshot, data, keys, markers);
            } catch (Exception restoreFailure) {
                failure.addSuppressed(restoreFailure);
            }
            throw failure;
        }
        // Every current data/key/marker file is now durable. A failed cleanup
        // may have cleared the journal's in-memory map despite returning false.
        // Leave the consistent current store intact in that case: restoring
        // multiple old files after losing the journal would create a new risk.
        // If the old journal survives on disk, the next process can restore it.
        journal.clear();
    }

    private static void restore(Snapshot snapshot, Store data, Store keys,
                                Store markers) throws Exception {
        data.replace(snapshot.data);
        keys.replace(snapshot.keys);
        markers.replace(snapshot.markers);
    }

    private LegacyMigrationTransaction() {}
}
