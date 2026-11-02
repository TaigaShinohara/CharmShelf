package com.it_nomads.fluttersecurestorage;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Base64;

import com.google.crypto.tink.Aead;
import com.google.crypto.tink.DeterministicAead;
import com.google.crypto.tink.RegistryConfiguration;
import com.google.crypto.tink.aead.AeadConfig;
import com.google.crypto.tink.daead.DeterministicAeadConfig;
import com.google.crypto.tink.integration.android.AndroidKeysetManager;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipherFactory;

import org.json.JSONArray;
import org.json.JSONObject;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.spec.MGF1ParameterSpec;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.OAEPParameterSpec;
import javax.crypto.spec.PSource;

/**
 * TagShelf's upgrade bridge for versions that used v9 EncryptedSharedPreferences
 * or the RSA-PKCS1/AES-CBC format removed by v11. The decoder follows the v10.3.4
 * wire formats; it never creates, deletes, or replaces a legacy Keystore key.
 * All temporary on-disk state is original ciphertext, never decrypted values.
 */
final class LegacyStorageMigration {
    private static final Object LOCK = new Object();
    static final String KEY_MARKER = "FlutterSecureSAlgorithmKey";
    static final String STORAGE_MARKER = "FlutterSecureSAlgorithmStorage";
    static final String KEYSET = "__androidx_security_crypto_encrypted_prefs_key_keyset__";
    static final String VALUE_KEYSET = "__androidx_security_crypto_encrypted_prefs_value_keyset__";
    static final String CBC_WRAPPED_KEY = "VGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdlIEFFUyBLZXkK";
    static final String GCM_WRAPPED_KEY = "AES" + CBC_WRAPPED_KEY;
    static final String LEGACY_V9_GCM_WRAPPED_KEY = "VGhpcyBpcyB0aGUga2V5IGZvcihBIHNlY3XyZZBzdG9yYWdlIEFFUyBLZXkK";
    private static final String CURRENT_KEY = "RSA_ECB_OAEPwithSHA_256andMGF1Padding";
    private static final String CURRENT_STORAGE = "AES_GCM_NoPadding";
    private static final String MASTER_ALIAS = "_androidx_security_master_key_";

    static void migrate(Context context, FlutterSecureStorageConfig config) throws Exception {
        synchronized (LOCK) {
            final String name = config.getEffectiveDataPrefsName();
            PreferenceStore data = new PreferenceStore(context.getSharedPreferences(name, 0));
            PreferenceStore keys = new PreferenceStore(context.getSharedPreferences(
                    config.getEffectiveKeyStoragePrefsName(), 0));
            PreferenceStore markers = new PreferenceStore(context.getSharedPreferences(
                    "FlutterSecureStorageConfiguration:" + name, 0));
            PreferenceJournal journal = new PreferenceJournal(context.getSharedPreferences(
                    "FlutterSecureStorageLegacyMigration:" + name, 0));
            LegacyMigrationTransaction.run(data, keys, markers, journal,
                    new AndroidMigration(context, config, data, keys, markers));
        }
    }

    static void persistCurrentMetadata(Context context, FlutterSecureStorageConfig config,
                                        StorageCipherFactory factory) throws Exception {
        PreferenceStore keys = new PreferenceStore(context.getSharedPreferences(
                config.getEffectiveKeyStoragePrefsName(), 0));
        keys.replace(keys.read());
        SharedPreferences.Editor markers = new NamespacedConfigSource(context,
                config.getEffectiveDataPrefsName()).edit();
        factory.storeCurrentAlgorithms(markers);
        if (!markers.commit()) throw new IllegalStateException("Secure storage initialization commit failed");
    }

    private static final class AndroidMigration implements LegacyMigrationTransaction.Migration {
        private final Context context;
        private final FlutterSecureStorageConfig config;
        private final PreferenceStore data;
        private final PreferenceStore keys;
        private final PreferenceStore markers;

        AndroidMigration(Context context, FlutterSecureStorageConfig config, PreferenceStore data,
                         PreferenceStore keys, PreferenceStore markers) {
            this.context = context;
            this.config = config;
            this.data = data;
            this.keys = keys;
            this.markers = markers;
        }

        @Override
        public boolean needed() {
            Map<String, Object> raw = data.read();
            if (hasEspEntries(raw, config.getSharedPreferencesKeyPrefix())) return true;
            if (!hasCustomEntries(raw, config.getSharedPreferencesKeyPrefix())) return false;
            Map<String, Object> wrappedKeys = keys.read();
            if (wrappedKeys.containsKey(LEGACY_V9_GCM_WRAPPED_KEY)
                    && !wrappedKeys.containsKey(GCM_WRAPPED_KEY)) return true;
            String keyAlgorithm = savedMarker(KEY_MARKER, raw);
            String storageAlgorithm = savedMarker(STORAGE_MARKER, raw);
            return keyAlgorithm == null || storageAlgorithm == null
                    || "RSA_ECB_PKCS1Padding".equals(keyAlgorithm)
                    || "AES_CBC_PKCS7Padding".equals(storageAlgorithm);
        }

        private String savedMarker(String key, Map<String, Object> raw) {
            return LegacyStorageMigration.savedMarker(key, markers.read(), raw, new HashMap<>(context
                    .getSharedPreferences("FlutterSecureStorageConfiguration", 0).getAll()));
        }

        @Override
        public void apply() throws Exception {
            // TagShelf has always used non-biometric storage with the default algorithms.
            // Refuse an unexpected configuration rather than silently weakening it.
            if (config.shouldDeleteOnFailure() || !config.shouldMigrateWithBackup()
                    || !CURRENT_KEY.equals(config.getPrefOptionKeyCipherAlgorithm())
                    || !CURRENT_STORAGE.equals(config.getPrefOptionStorageCipherAlgorithm())) {
                throw new IllegalStateException("Legacy upgrade requires protected default storage options");
            }
            Map<String, Object> raw = data.read();
            Map<String, String> plain = new HashMap<>();
            Set<String> oldEspKeys = new HashSet<>();
            String prefix = config.getSharedPreferencesKeyPrefix() + "_";
            if (!hasEspEntries(raw, config.getSharedPreferencesKeyPrefix())) {
                requireSingleCustomPrefix(raw, config.getSharedPreferencesKeyPrefix());
            }
            if (hasCustomEntries(raw, config.getSharedPreferencesKeyPrefix())) {
                String keyAlgorithm = savedMarker(KEY_MARKER, raw);
                String storageAlgorithm = savedMarker(STORAGE_MARKER, raw);
                if (keyAlgorithm == null) keyAlgorithm = "RSA_ECB_PKCS1Padding";
                if (storageAlgorithm == null) storageAlgorithm = "AES_CBC_PKCS7Padding";
                boolean gcm = CURRENT_STORAGE.equals(storageAlgorithm);
                if (!gcm && !"AES_CBC_PKCS7Padding".equals(storageAlgorithm)) {
                    throw new IllegalStateException("Unrecognised legacy storage algorithm");
                }
                String wrapped = savedWrappedKey(keys.read(), gcm);
                Key aes = unwrapExistingKey(context, config, keyAlgorithm, wrapped);
                for (Map.Entry<String, Object> entry : raw.entrySet()) {
                    if (!entry.getKey().startsWith(prefix)) continue;
                    if (!(entry.getValue() instanceof String)) {
                        throw new IllegalStateException("Unrecognised legacy entry type");
                    }
                    byte[] decoded = decryptCustom(Base64.decode((String) entry.getValue(), 0), aes, gcm);
                    plain.put(entry.getKey(), utf8(decoded));
                }
            }
            if (hasEspEntries(raw, config.getSharedPreferencesKeyPrefix())) {
                decodeEsp(context, config, raw, plain, oldEspKeys);
            }

            // Nothing is replaced until every old value has been successfully decoded.
            Map<String, Object> currentKeys = keys.read();
            currentKeys.remove(GCM_WRAPPED_KEY);
            keys.replace(currentKeys);
            StorageCipher current = new StorageCipherFactory(
                    new NamespacedConfigSource(context, config.getEffectiveDataPrefsName()),
                    CURRENT_KEY, CURRENT_STORAGE, config).getCurrentStorageCipher(context, null);
            // The upstream constructor uses apply() for the generated wrapped key.
            // Commit that same preference file before replacing any ciphertext or
            // clearing the only journal capable of restoring the original key.
            keys.replace(keys.read());
            Map<String, Object> replacement = new HashMap<>(raw);
            for (String key : oldEspKeys) replacement.remove(key);
            for (Map.Entry<String, String> entry : plain.entrySet()) {
                byte[] encoded = current.encrypt(entry.getValue().getBytes(StandardCharsets.UTF_8));
                if (!entry.getValue().equals(utf8(current.decrypt(encoded)))) {
                    throw new IllegalStateException("Migrated value failed round-trip verification");
                }
                replacement.put(entry.getKey(), Base64.encodeToString(encoded, Base64.DEFAULT));
            }
            // The two durable commits are protected by the original encrypted journal.
            data.replace(replacement);
            Map<String, Object> currentMarkers = markers.read();
            currentMarkers.put(KEY_MARKER, CURRENT_KEY);
            currentMarkers.put(STORAGE_MARKER, CURRENT_STORAGE);
            currentMarkers.put("ENCRYPTED_PREFERENCES_MIGRATED", true);
            markers.replace(currentMarkers);
        }
    }

    static boolean hasCustomEntries(Map<String, Object> entries, String prefix) {
        for (String key : entries.keySet()) if (key.startsWith(prefix + "_")) return true;
        return false;
    }

    static String savedMarker(String key, Map<String, Object> namespaced,
                               Map<String, Object> data, Map<String, Object> legacyGlobal) {
        // A global marker may belong to another store. v9's explicit data-store
        // marker must win over that compatibility fallback.
        Object value = namespaced.get(key);
        if (value == null) value = data.get(key);
        if (value == null) value = legacyGlobal.get(key);
        return value instanceof String ? (String) value : null;
    }

    static String savedWrappedKey(Map<String, Object> keys, boolean gcm) {
        Object value = keys.get(gcm ? GCM_WRAPPED_KEY : CBC_WRAPPED_KEY);
        if (value == null && gcm) value = keys.get(LEGACY_V9_GCM_WRAPPED_KEY);
        if (!(value instanceof String)) throw new IllegalStateException("Legacy wrapped key is missing");
        return (String) value;
    }

    static void requireSingleCustomPrefix(Map<String, Object> entries, String prefix) {
        for (String key : entries.keySet()) {
            if (key.startsWith(prefix + "_") || key.equals(KEYSET) || key.equals(VALUE_KEYSET)
                    || key.equals(KEY_MARKER) || key.equals(STORAGE_MARKER)) continue;
            // Algorithm markers and the wrapped AES key are shared by all prefixes
            // in a store. TagShelf uses one prefix; refuse to rotate another store's
            // key or change its markers while leaving its ciphertext behind.
            throw new IllegalStateException("Legacy store contains an unsupported shared key prefix");
        }
    }

    static boolean hasEspEntries(Map<String, Object> entries, String prefix) {
        if (!entries.containsKey(KEYSET) && !entries.containsKey(VALUE_KEYSET)) return false;
        for (String key : entries.keySet()) {
            if (!key.equals(KEYSET) && !key.equals(VALUE_KEYSET)
                    && !key.startsWith("FlutterSecureSAlgorithm")
                    && !key.startsWith(prefix + "_")) {
                return true;
            }
        }
        return false;
    }

    private static void decodeEsp(Context context, FlutterSecureStorageConfig config,
                                  Map<String, Object> raw, Map<String, String> plain,
                                  Set<String> oldKeys) throws Exception {
        if (!(raw.get(KEYSET) instanceof String) || !(raw.get(VALUE_KEYSET) instanceof String)) {
            throw new IllegalStateException("Legacy encrypted preference keyset is incomplete");
        }
        KeyStore store = KeyStore.getInstance("AndroidKeyStore");
        store.load(null);
        if (!store.containsAlias(MASTER_ALIAS)) {
            throw new IllegalStateException("Legacy encrypted preference master key is missing");
        }
        DeterministicAeadConfig.register();
        AeadConfig.register();
        // Existing keysets and master key were checked above. Do not supply templates:
        // missing key material must fail rather than generating a replacement.
        DeterministicAead keyAead = new AndroidKeysetManager.Builder()
                .withSharedPref(context, KEYSET, config.getEffectiveDataPrefsName())
                .withMasterKeyUri("android-keystore://" + MASTER_ALIAS).build()
                .getKeysetHandle().getPrimitive(RegistryConfiguration.get(), DeterministicAead.class);
        Aead valueAead = new AndroidKeysetManager.Builder()
                .withSharedPref(context, VALUE_KEYSET, config.getEffectiveDataPrefsName())
                .withMasterKeyUri("android-keystore://" + MASTER_ALIAS).build()
                .getKeysetHandle().getPrimitive(RegistryConfiguration.get(), Aead.class);
        decodeEspEntries(raw, plain, oldKeys, keyAead, valueAead,
                config.getEffectiveDataPrefsName(), config.getSharedPreferencesKeyPrefix());
    }

    static void decodeEspEntries(Map<String, Object> raw, Map<String, String> plain,
                                 Set<String> oldKeys, DeterministicAead keyAead, Aead valueAead,
                                 String preferenceName, String keyPrefix) throws Exception {
        String prefix = keyPrefix + "_";
        for (Map.Entry<String, Object> entry : raw.entrySet()) {
            String encryptedKey = entry.getKey();
            if (encryptedKey.equals(KEYSET) || encryptedKey.equals(VALUE_KEYSET)
                    || encryptedKey.startsWith(prefix) || encryptedKey.startsWith("FlutterSecureSAlgorithm")) continue;
            String key = utf8(keyAead.decryptDeterministically(Base64.decode(encryptedKey, 0),
                    preferenceName.getBytes(StandardCharsets.UTF_8)));
            if (!key.startsWith(prefix)) {
                throw new IllegalStateException("Legacy encrypted store contains an unsupported shared key prefix");
            }
            if (!(entry.getValue() instanceof String)) throw new IllegalStateException("Invalid legacy encrypted entry");
            String value = decodeEspString(valueAead.decrypt(Base64.decode((String) entry.getValue(), 0),
                    encryptedKey.getBytes(StandardCharsets.UTF_8)));
            // A partially completed v10 ESP migration may contain both representations.
            // Do not discard either if their decoded values disagree.
            if (plain.containsKey(key) && !plain.get(key).equals(value)) {
                throw new IllegalStateException("Conflicting legacy secure storage values");
            }
            plain.put(key, value);
            oldKeys.add(encryptedKey);
        }
    }

    private static Key unwrapExistingKey(Context context, FlutterSecureStorageConfig config,
                                          String algorithm, String wrapped) throws Exception {
        boolean pkcs1 = "RSA_ECB_PKCS1Padding".equals(algorithm);
        if (!pkcs1 && !CURRENT_KEY.equals(algorithm)) {
            throw new IllegalStateException("Unrecognised legacy key algorithm");
        }
        String alias = context.getPackageName() + ".FlutterSecureStoragePluginKey"
                + (pkcs1 ? "" : "OAEP") + config.getKeyAliasSuffix();
        KeyStore store = KeyStore.getInstance("AndroidKeyStore");
        store.load(null);
        Key key = store.getKey(alias, null);
        if (!(key instanceof PrivateKey)) throw new IllegalStateException("Legacy private key is missing");
        // Match the upstream AndroidKeyStore path. The ordinary JCE provider
        // used by synthetic fixtures does not accept every Android Keystore key.
        return unwrapKey((PrivateKey) key, Base64.decode(wrapped, 0), pkcs1,
                "AndroidKeyStoreBCWorkaround");
    }

    static Key unwrapKey(PrivateKey key, byte[] wrapped, boolean pkcs1) throws Exception {
        return unwrapKey(key, wrapped, pkcs1, null);
    }

    private static Key unwrapKey(PrivateKey key, byte[] wrapped, boolean pkcs1,
                                 String provider) throws Exception {
        String transformation = pkcs1 ? "RSA/ECB/PKCS1Padding" : "RSA/ECB/OAEPPadding";
        Cipher rsa = provider == null ? Cipher.getInstance(transformation)
                : Cipher.getInstance(transformation, provider);
        if (pkcs1) rsa.init(Cipher.UNWRAP_MODE, key);
        else rsa.init(Cipher.UNWRAP_MODE, key,
                new OAEPParameterSpec("SHA-256", "MGF1", MGF1ParameterSpec.SHA1, PSource.PSpecified.DEFAULT));
        return rsa.unwrap(wrapped, "AES", Cipher.SECRET_KEY);
    }

    static byte[] decryptCustom(byte[] encoded, Key key, boolean gcm) throws Exception {
        int ivLength = gcm ? 12 : 16;
        if (encoded.length <= ivLength) throw new IllegalArgumentException("Truncated legacy ciphertext");
        Cipher cipher = Cipher.getInstance(gcm ? "AES/GCM/NoPadding" : "AES/CBC/PKCS5Padding");
        byte[] iv = Arrays.copyOf(encoded, ivLength);
        if (gcm) cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(128, iv));
        else cipher.init(Cipher.DECRYPT_MODE, key, new IvParameterSpec(iv));
        return cipher.doFinal(Arrays.copyOfRange(encoded, ivLength, encoded.length));
    }

    static String decodeEspString(byte[] encoded) throws Exception {
        ByteBuffer buffer = ByteBuffer.wrap(encoded);
        if (buffer.remaining() < 8 || buffer.getInt() != 0) {
            throw new IllegalArgumentException("Legacy secure storage value is not a string");
        }
        int length = buffer.getInt();
        if (length < 0 || length != buffer.remaining()) throw new IllegalArgumentException("Truncated legacy value");
        byte[] value = new byte[length];
        buffer.get(value);
        String decoded = utf8(value);
        if ("__NULL__".equals(decoded)) throw new IllegalArgumentException("Unexpected legacy null value");
        return decoded;
    }

    private static String utf8(byte[] bytes) throws Exception {
        return StandardCharsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(bytes)).toString();
    }

    static final class PreferenceStore implements LegacyMigrationTransaction.Store {
        final SharedPreferences preferences;
        PreferenceStore(SharedPreferences preferences) { this.preferences = preferences; }
        @Override public Map<String, Object> read() { return new HashMap<>(preferences.getAll()); }
        @Override public void replace(Map<String, Object> entries) throws Exception {
            SharedPreferences.Editor editor = preferences.edit().clear();
            for (Map.Entry<String, Object> entry : entries.entrySet()) put(editor, entry.getKey(), entry.getValue());
            if (!editor.commit()) throw new IllegalStateException("Secure storage commit failed");
        }
    }

    private static void put(SharedPreferences.Editor editor, String key, Object value) {
        if (value instanceof String) editor.putString(key, (String) value);
        else if (value instanceof Boolean) editor.putBoolean(key, (Boolean) value);
        else if (value instanceof Integer) editor.putInt(key, (Integer) value);
        else if (value instanceof Long) editor.putLong(key, (Long) value);
        else if (value instanceof Float) editor.putFloat(key, (Float) value);
        else if (value instanceof Set) {
            @SuppressWarnings("unchecked") Set<String> set = (Set<String>) value;
            editor.putStringSet(key, new HashSet<>(set));
        } else throw new IllegalArgumentException("Unsupported secure storage preference type");
    }

    static final class PreferenceJournal implements LegacyMigrationTransaction.Journal {
        final SharedPreferences preferences;
        PreferenceJournal(SharedPreferences preferences) { this.preferences = preferences; }
        @Override public LegacyMigrationTransaction.Snapshot load() throws Exception {
            String saved = preferences.getString("ciphertextSnapshot", null);
            if (saved == null) return null;
            JSONObject object = new JSONObject(saved);
            return new LegacyMigrationTransaction.Snapshot(decode(object.getJSONObject("data")),
                    decode(object.getJSONObject("keys")), decode(object.getJSONObject("markers")));
        }
        @Override public void save(LegacyMigrationTransaction.Snapshot snapshot) throws Exception {
            JSONObject object = new JSONObject();
            object.put("data", encode(snapshot.data)); object.put("keys", encode(snapshot.keys));
            object.put("markers", encode(snapshot.markers));
            if (!preferences.edit().putString("ciphertextSnapshot", object.toString()).commit()) {
                throw new IllegalStateException("Secure storage migration journal commit failed");
            }
        }
        @Override public void clear() throws Exception {
            if (!preferences.edit().clear().commit()) throw new IllegalStateException("Secure storage journal cleanup failed");
        }
        private static JSONObject encode(Map<String, Object> entries) throws Exception {
            JSONObject object = new JSONObject();
            for (Map.Entry<String, Object> entry : entries.entrySet()) {
                Object value = entry.getValue();
                JSONArray pair = new JSONArray();
                if (value instanceof Set) { pair.put("set"); pair.put(new JSONArray((Set<?>) value)); }
                else if (value instanceof Long) { pair.put("long"); pair.put(value.toString()); }
                else if (value instanceof Float) { pair.put("float"); pair.put(value.toString()); }
                else if (value instanceof String) { pair.put("string"); pair.put(value); }
                else if (value instanceof Integer) { pair.put("int"); pair.put(value); }
                else if (value instanceof Boolean) { pair.put("bool"); pair.put(value); }
                else throw new IllegalArgumentException("Unsupported journal preference type");
                object.put(entry.getKey(), pair);
            }
            return object;
        }
        private static Map<String, Object> decode(JSONObject object) throws Exception {
            Map<String, Object> result = new HashMap<>();
            for (Iterator<String> iterator = object.keys(); iterator.hasNext();) {
                String key = iterator.next(); JSONArray pair = object.getJSONArray(key); Object value;
                switch (pair.getString(0)) {
                    case "long": value = Long.parseLong(pair.getString(1)); break;
                    case "float": value = Float.parseFloat(pair.getString(1)); break;
                    case "string": value = pair.getString(1); break;
                    case "int": value = pair.getInt(1); break;
                    case "bool": value = pair.getBoolean(1); break;
                    case "set": {
                        Set<String> set = new HashSet<>(); JSONArray items = pair.getJSONArray(1);
                        for (int i = 0; i < items.length(); i++) set.add(items.getString(i));
                        value = set; break;
                    }
                    default: throw new IllegalArgumentException("Unrecognised journal preference type");
                }
                result.put(key, value);
            }
            return result;
        }
    }

    private LegacyStorageMigration() {}
}
