package com.it_nomads.fluttersecurestorage;

import android.content.Context;
import android.util.Base64;

import com.google.crypto.tink.Aead;
import com.google.crypto.tink.DeterministicAead;
import com.google.crypto.tink.KeyTemplates;
import com.google.crypto.tink.KeysetHandle;
import com.google.crypto.tink.RegistryConfiguration;
import com.google.crypto.tink.aead.AeadConfig;
import com.google.crypto.tink.daead.DeterministicAeadConfig;
import com.it_nomads.fluttersecurestorage.ciphers.KeyCipher;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipherImplementationGCM;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

import java.lang.reflect.Field;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicReference;

import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;

import static org.junit.Assert.*;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public class LegacyStorageMigrationTest {
    private Context context;
    private FlutterSecureStorageConfig config;
    private String prefix;

    @Before public void setUp() throws Exception {
        context = RuntimeEnvironment.getApplication();
        config = new FlutterSecureStorageConfig(Map.of("resetOnError", "false", "migrateWithBackup", "true"));
        prefix = config.getSharedPreferencesKeyPrefix();
        context.getSharedPreferences(config.getEffectiveDataPrefsName(), 0).edit().clear().commit();
        context.getSharedPreferences(config.getEffectiveKeyStoragePrefsName(), 0).edit().clear().commit();
        DeterministicAeadConfig.register(); AeadConfig.register();
    }

    private static final class FakeKeyCipher implements KeyCipher {
        @Override public byte[] wrap(Key key) { return key.getEncoded(); }
        @Override public Key unwrap(byte[] wrapped, String algorithm) { return new SecretKeySpec(wrapped, algorithm); }
        @Override public Cipher getCipher(Context context) { return null; }
        @Override public void deleteKey() { fail("Migration must retain legacy Keystore keys"); }
    }

    /** Reopens the migrated ciphertext through the real v11 read implementation. */
    private String writeAndReadWithV11(String value) throws Exception {
        StorageCipher first = new StorageCipherImplementationGCM(context, new FakeKeyCipher(), null, config);
        String key = prefix + "_pin_code";
        byte[] encrypted = first.encrypt(value.getBytes(StandardCharsets.UTF_8));
        var preferences = context.getSharedPreferences(config.getEffectiveDataPrefsName(), 0);
        assertTrue(preferences.edit().putString(key, Base64.encodeToString(encrypted, 0)).commit());
        StorageCipher reopened = new StorageCipherImplementationGCM(context, new FakeKeyCipher(), null, config);
        FlutterSecureStorage storage = new FlutterSecureStorage(context);
        for (Map.Entry<String, Object> entry : Map.of("config", config, "preferences", preferences,
                "storageCipher", reopened).entrySet()) {
            Field field = FlutterSecureStorage.class.getDeclaredField(entry.getKey());
            field.setAccessible(true); field.set(storage, entry.getValue());
        }
        AtomicReference<String> result = new AtomicReference<>();
        AtomicReference<Exception> failure = new AtomicReference<>();
        storage.read(key, new SecurePreferencesCallback<>() {
            @Override public void onSuccess(String read) { result.set(read); }
            @Override public void onError(Exception error) { failure.set(error); }
        });
        assertNull(failure.get());
        return result.get();
    }

    @Test public void v9RsaPkcs1AesCbcFixtureCanBeReadByV11AfterUpgrade() throws Exception {
        byte[] synthetic = "synthetic-pin-hash-v2-日本語".getBytes(StandardCharsets.UTF_8);
        SecretKeySpec aes = new SecretKeySpec(new byte[16], "AES");
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA"); generator.initialize(2048);
        KeyPair rsa = generator.generateKeyPair();
        Cipher wrap = Cipher.getInstance("RSA/ECB/PKCS1Padding");
        wrap.init(Cipher.WRAP_MODE, rsa.getPublic());
        Key recovered = LegacyStorageMigration.unwrapKey(rsa.getPrivate(), wrap.wrap(aes), true);
        byte[] iv = new byte[16]; iv[0] = 7;
        Cipher old = Cipher.getInstance("AES/CBC/PKCS5Padding"); old.init(Cipher.ENCRYPT_MODE, aes, new IvParameterSpec(iv));
        byte[] payload = old.doFinal(synthetic);
        byte[] stored = ByteBuffer.allocate(iv.length + payload.length).put(iv).put(payload).array();
        String decoded = new String(LegacyStorageMigration.decryptCustom(stored, recovered, false), StandardCharsets.UTF_8);
        assertEquals(new String(synthetic, StandardCharsets.UTF_8), writeAndReadWithV11(decoded));
    }

    @Test public void realTinkEspWireFormatKeepsPinAndNamespaceAssociatedData() throws Exception {
        DeterministicAead names = KeysetHandle.generateNew(KeyTemplates.get("AES256_SIV"))
                .getPrimitive(RegistryConfiguration.get(), DeterministicAead.class);
        Aead values = KeysetHandle.generateNew(KeyTemplates.get("AES256_GCM"))
                .getPrimitive(RegistryConfiguration.get(), Aead.class);
        String prefName = config.getEffectiveDataPrefsName();
        String key = prefix + "_pin_code";
        String encodedKey = Base64.encodeToString(names.encryptDeterministically(key.getBytes(StandardCharsets.UTF_8),
                prefName.getBytes(StandardCharsets.UTF_8)), 0);
        byte[] value = "synthetic-legacy-pin".getBytes(StandardCharsets.UTF_8);
        byte[] serialized = ByteBuffer.allocate(8 + value.length).putInt(0).putInt(value.length).put(value).array();
        Map<String, Object> raw = Map.of(encodedKey, Base64.encodeToString(values.encrypt(serialized,
                encodedKey.getBytes(StandardCharsets.UTF_8)), 0));
        Map<String, String> decoded = new HashMap<>(); Set<String> original = new HashSet<>();
        LegacyStorageMigration.decodeEspEntries(raw, decoded, original, names, values, prefName, prefix);
        assertEquals(Set.of(encodedKey), original);
        assertEquals("synthetic-legacy-pin", writeAndReadWithV11(decoded.get(key)));
        assertThrows(Exception.class, () -> LegacyStorageMigration.decodeEspEntries(raw, new HashMap<>(),
                new HashSet<>(), names, values, "different-namespace", prefix));
    }

    @Test public void v9GcmTypoWrappedKeyNameIsUsedWithoutReplacingTheOldKey() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA"); generator.initialize(2048);
        KeyPair rsa = generator.generateKeyPair();
        SecretKeySpec aes = new SecretKeySpec(new byte[16], "AES");
        Cipher wrap = Cipher.getInstance("RSA/ECB/PKCS1Padding"); wrap.init(Cipher.WRAP_MODE, rsa.getPublic());
        Map<String, Object> oldKeys = Map.of("VGhpcyBpcyB0aGUga2V5IGZvcihBIHNlY3XyZZBzdG9yYWdlIEFFUyBLZXkK",
                Base64.encodeToString(wrap.wrap(aes), 0));
        String saved = LegacyStorageMigration.savedWrappedKey(oldKeys, true);
        Key recovered = LegacyStorageMigration.unwrapKey(rsa.getPrivate(), Base64.decode(saved, 0), true);
        byte[] iv = new byte[12]; iv[0] = 3;
        Cipher old = Cipher.getInstance("AES/GCM/NoPadding");
        old.init(Cipher.ENCRYPT_MODE, aes, new GCMParameterSpec(128, iv));
        byte[] encrypted = old.doFinal("synthetic-old-gcm".getBytes(StandardCharsets.UTF_8));
        byte[] stored = ByteBuffer.allocate(iv.length + encrypted.length).put(iv).put(encrypted).array();
        String decoded = new String(LegacyStorageMigration.decryptCustom(stored, recovered, true), StandardCharsets.UTF_8);
        assertEquals("synthetic-old-gcm", writeAndReadWithV11(decoded));
        assertEquals(1, oldKeys.size());
    }

    @Test public void corruptOrUnexpectedLegacyValuesFailInsteadOfBecomingEmpty() {
        assertThrows(Exception.class, () -> LegacyStorageMigration.decryptCustom(new byte[2],
                new SecretKeySpec(new byte[16], "AES"), false));
        assertThrows(Exception.class, () -> LegacyStorageMigration.decodeEspString(new byte[0]));
        assertThrows(Exception.class, () -> LegacyStorageMigration.decodeEspString(
                ByteBuffer.allocate(8).putInt(0).putInt(100).array()));
        assertThrows(Exception.class, () -> LegacyStorageMigration.decodeEspString(
                ByteBuffer.allocate(8).putInt(2).putInt(0).array()));
    }

    @Test public void journalRoundTripPreservesRawCiphertextKeyBlobsAndMarkerTypes() throws Exception {
        var journal = new LegacyStorageMigration.PreferenceJournal(context.getSharedPreferences("synthetic-journal", 0));
        Map<String, Object> original = Map.of("cipher", "BASE64_CIPHERTEXT", "flag", true, "long", 99999999999L,
                "integer", 3, "float", 1.25f, "set", Set.of("one", "two"));
        journal.save(new LegacyMigrationTransaction.Snapshot(original, Map.of("key", "WRAPPED_KEY"), Map.of("old", false)));
        LegacyMigrationTransaction.Snapshot restored = journal.load();
        assertEquals(original, restored.data); assertEquals("WRAPPED_KEY", restored.keys.get("key"));
        assertEquals(false, restored.markers.get("old")); journal.clear(); assertNull(journal.load());
    }

    @Test public void explicitV9StoreMarkersWinOverAnotherStoresGlobalMarkers() {
        String key = LegacyStorageMigration.KEY_MARKER;
        Map<String, Object> oldData = Map.of(key, "RSA_ECB_PKCS1Padding");
        Map<String, Object> global = Map.of(key, "RSA_ECB_OAEPwithSHA_256andMGF1Padding");
        assertEquals("RSA_ECB_PKCS1Padding", LegacyStorageMigration.savedMarker(key, Map.of(), oldData, global));
        assertEquals("namespaced", LegacyStorageMigration.savedMarker(key, Map.of(key, "namespaced"), oldData, global));
    }

    @Test public void sharedKeyPrefixesAreRejectedBeforeRotatingTheirSharedWrappedKey() {
        Map<String, Object> raw = Map.of("prefixA_pin", "CIPHER_A", "prefixB_pin", "CIPHER_B");
        assertThrows(IllegalStateException.class,
                () -> LegacyStorageMigration.requireSingleCustomPrefix(raw, "prefixA"));
        assertEquals(Map.of("prefixA_pin", "CIPHER_A", "prefixB_pin", "CIPHER_B"), raw);
        LegacyStorageMigration.requireSingleCustomPrefix(Map.of(prefix + "_pin", "CIPHER"), prefix);
    }
}
