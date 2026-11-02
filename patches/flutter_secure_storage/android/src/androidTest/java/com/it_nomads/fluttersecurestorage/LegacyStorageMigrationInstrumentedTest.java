package com.it_nomads.fluttersecurestorage;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.Process;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import com.google.crypto.tink.Aead;
import com.google.crypto.tink.DeterministicAead;
import com.google.crypto.tink.KeyTemplates;
import com.google.crypto.tink.RegistryConfiguration;
import com.google.crypto.tink.aead.AeadConfig;
import com.google.crypto.tink.daead.DeterministicAeadConfig;
import com.google.crypto.tink.integration.android.AndroidKeysetManager;
import com.google.crypto.tink.proto.EncryptedKeyset;
import com.google.crypto.tink.subtle.Hex;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;

import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.SecureRandom;
import java.util.Calendar;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import javax.security.auth.x500.X500Principal;

/**
 * Synthetic upgrade fixtures only. This library's self-targeting test APK owns
 * every preference and AndroidKeyStore alias used here; no TagShelf app context
 * is opened. The fixture wire names are literal legacy values, independent of
 * the bridge constants, so a typo in production cannot also change the fixture.
 */
@RunWith(AndroidJUnit4.class)
public final class LegacyStorageMigrationInstrumentedTest {
    private static final String TEST_PACKAGE =
            "com.it_nomads.fluttersecurestorage.migrationtest";
    private static final String DATA_PREFS = "FlutterSecureStorage";
    private static final String KEY_PREFS = "FlutterSecureKeyStorage";
    private static final String CONFIG_PREFS = "FlutterSecureStorageConfiguration:" + DATA_PREFS;
    private static final String GLOBAL_CONFIG_PREFS = "FlutterSecureStorageConfiguration";
    private static final String JOURNAL_PREFS = "FlutterSecureStorageLegacyMigration:" + DATA_PREFS;
    private static final String PREFIX =
            "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg";
    private static final String CBC_WRAPPED_KEY =
            "VGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdlIEFFUyBLZXkK";
    private static final String CURRENT_GCM_WRAPPED_KEY = "AES" + CBC_WRAPPED_KEY;
    private static final String V9_GCM_WRAPPED_KEY =
            "VGhpcyBpcyB0aGUga2V5IGZvcihBIHNlY3XyZZBzdG9yYWdlIEFFUyBLZXkK";
    private static final String KEY_ALGORITHM = "FlutterSecureSAlgorithmKey";
    private static final String STORAGE_ALGORITHM = "FlutterSecureSAlgorithmStorage";
    private static final String KEYSET =
            "__androidx_security_crypto_encrypted_prefs_key_keyset__";
    private static final String VALUE_KEYSET =
            "__androidx_security_crypto_encrypted_prefs_value_keyset__";
    private static final String MASTER_ALIAS = "_androidx_security_master_key_";
    private static final String PKCS1_ALIAS = TEST_PACKAGE + ".FlutterSecureStoragePluginKey";
    private static final String OAEP_ALIAS = PKCS1_ALIAS + "OAEP";

    private Context context;
    private FlutterSecureStorageConfig config;

    @Before
    public void setUp() throws Exception {
        // Check all isolation conditions before the first cleanup or key creation.
        assertEquals("true", InstrumentationRegistry.getArguments()
                .getString("tagshelfSyntheticStorageMigration"));
        assertTrue("Run only on the dedicated Android emulator",
                "ranchu".equals(Build.HARDWARE) || "goldfish".equals(Build.HARDWARE));
        Context target = InstrumentationRegistry.getInstrumentation().getTargetContext();
        assertEquals(TEST_PACKAGE, target.getPackageName());
        assertEquals(TEST_PACKAGE, InstrumentationRegistry.getInstrumentation()
                .getContext().getPackageName());
        assertEquals(Process.myUid(), target.getApplicationInfo().uid);
        assertNotNull(target.getApplicationContext());
        assertEquals(TEST_PACKAGE, target.getApplicationContext().getPackageName());
        context = target.getApplicationContext();
        clearSyntheticState();
        Map<String, Object> options = new HashMap<>();
        options.put("resetOnError", "false");
        options.put("migrateWithBackup", "true");
        config = new FlutterSecureStorageConfig(options);
        assertEquals(DATA_PREFS, config.getEffectiveDataPrefsName());
        assertEquals(KEY_PREFS, config.getEffectiveKeyStoragePrefsName());
        assertEquals(PREFIX, config.getSharedPreferencesKeyPrefix());
        assertFalse(config.getEnforceBiometrics());
        assertFalse(config.getRequireBiometricsPerOperation());
        assertFalse(config.hasStorageNamespace());
    }

    @After
    public void tearDown() throws Exception {
        if (context != null) clearSyntheticState();
    }

    @Test
    public void encryptedSharedPreferencesMigratesWithRealMasterKeyAndReopens() throws Exception {
        Map<String, String> expected = fixtureValues();
        seedEncryptedPreferences(expected);
        Map<String, ?> old = snapshot(DATA_PREFS);
        assertTrue(keyStore().containsAlias(MASTER_ALIAS));

        migrateReadAndReopen(expected);

        assertTrue("The original legacy master key must remain", keyStore().containsAlias(MASTER_ALIAS));
        assertEquals(old.get(KEYSET), preferences(DATA_PREFS).getString(KEYSET, null));
        assertEquals(old.get(VALUE_KEYSET), preferences(DATA_PREFS).getString(VALUE_KEYSET, null));
        for (String encryptedKey : old.keySet()) {
            if (!encryptedKey.equals(KEYSET) && !encryptedKey.equals(VALUE_KEYSET)) {
                assertFalse(preferences(DATA_PREFS).contains(encryptedKey));
            }
        }
    }

    @Test
    public void rsaPkcs1CbcWithoutMarkersMigratesAndReopens() throws Exception {
        Map<String, String> expected = fixtureValues();
        seedRsaPkcs1(expected, false);
        byte[] legacyCertificate = keyStore().getCertificate(PKCS1_ALIAS).getEncoded();
        String originalWrappedKey = preferences(KEY_PREFS).getString(CBC_WRAPPED_KEY, null);

        migrateReadAndReopen(expected);

        assertArrayEquals(legacyCertificate, keyStore().getCertificate(PKCS1_ALIAS).getEncoded());
        assertEquals(originalWrappedKey, preferences(KEY_PREFS).getString(CBC_WRAPPED_KEY, null));
    }

    @Test
    public void v9GcmWithOriginalTypoWrappedKeyMigratesAndReopens() throws Exception {
        Map<String, String> expected = fixtureValues();
        seedRsaPkcs1(expected, true);
        String originalWrappedKey = preferences(KEY_PREFS).getString(V9_GCM_WRAPPED_KEY, null);
        assertFalse(preferences(KEY_PREFS).contains(CURRENT_GCM_WRAPPED_KEY));

        migrateReadAndReopen(expected);

        assertEquals(originalWrappedKey, preferences(KEY_PREFS).getString(V9_GCM_WRAPPED_KEY, null));
        assertTrue(keyStore().containsAlias(PKCS1_ALIAS));
    }

    @Test
    public void initializeEntryPointMigratesEncryptedPreferencesWithoutManualMigration() throws Exception {
        Map<String, String> expected = fixtureValues();
        seedEncryptedPreferences(expected);
        FlutterSecureStorage storage = openStorage();
        assertReadable(storage, expected);
        assertCurrentState();
        assertReadable(openStorage(), expected);
    }

    @Test
    public void freshDefaultStorageWritesAndReopensAndMigrationIsIdempotent() throws Exception {
        LegacyStorageMigration.migrate(context, config);
        assertTrue(snapshot(DATA_PREFS).isEmpty());
        assertTrue(snapshot(KEY_PREFS).isEmpty());
        assertFalse(keyStore().containsAlias(OAEP_ALIAS));

        FlutterSecureStorage storage = openStorage();
        Map<String, String> expected = fixtureValues();
        for (Map.Entry<String, String> entry : expected.entrySet()) {
            write(storage, entry.getKey(), entry.getValue());
        }
        flushPreferences();
        assertReadable(openStorage(), expected);
        Map<String, ?> before = snapshot(DATA_PREFS);
        Map<String, ?> keysBefore = snapshot(KEY_PREFS);
        LegacyStorageMigration.migrate(context, config);
        assertEquals(before, snapshot(DATA_PREFS));
        assertEquals(keysBefore, snapshot(KEY_PREFS));
        assertReadable(openStorage(), expected);
    }

    @Test
    public void corruptLegacyCiphertextFailsWithoutResetOnRepeatedInitialize() throws Exception {
        Map<String, String> expected = fixtureValues();
        seedRsaPkcs1(expected, false);
        String rawKey = prefixed("unicode");
        assertTrue(preferences(DATA_PREFS).edit().putString(rawKey, "invalid-ciphertext").commit());
        Map<String, ?> damagedData = snapshot(DATA_PREFS);
        Map<String, ?> oldKeys = snapshot(KEY_PREFS);
        byte[] certificate = keyStore().getCertificate(PKCS1_ALIAS).getEncoded();

        for (int attempt = 0; attempt < 2; attempt++) {
            FlutterSecureStorage storage = new FlutterSecureStorage(context);
            awaitFailure(callback -> storage.initialize(config, callback));
            assertEquals(damagedData, snapshot(DATA_PREFS));
            assertEquals(oldKeys, snapshot(KEY_PREFS));
            assertArrayEquals(certificate, keyStore().getCertificate(PKCS1_ALIAS).getEncoded());
            assertFalse(keyStore().containsAlias(OAEP_ALIAS));
        }
        LegacyStorageMigration.PreferenceJournal journal =
                new LegacyStorageMigration.PreferenceJournal(preferences(JOURNAL_PREFS));
        assertNotNull(journal.load());
        assertEquals(damagedData, journal.load().data);
        assertEquals(oldKeys, journal.load().keys);
    }

    @Test
    public void missingEspMasterKeyFailsWithoutGeneratingReplacementOrReset() throws Exception {
        seedEncryptedPreferences(fixtureValues());
        Map<String, ?> oldData = snapshot(DATA_PREFS);
        keyStore().deleteEntry(MASTER_ALIAS);

        for (int attempt = 0; attempt < 2; attempt++) {
            try {
                LegacyStorageMigration.migrate(context, config);
                fail("Missing legacy master key must fail, never regenerate it");
            } catch (Exception expectedFailure) {
                assertEquals(oldData, snapshot(DATA_PREFS));
                assertTrue(snapshot(KEY_PREFS).isEmpty());
                assertFalse(keyStore().containsAlias(MASTER_ALIAS));
                assertFalse(keyStore().containsAlias(OAEP_ALIAS));
            }
        }
    }

    private void migrateReadAndReopen(Map<String, String> expected) throws Exception {
        LegacyStorageMigration.migrate(context, config);
        assertCurrentState();
        Map<String, ?> dataAfter = snapshot(DATA_PREFS);
        Map<String, ?> keysAfter = snapshot(KEY_PREFS);
        Map<String, ?> markersAfter = snapshot(CONFIG_PREFS);
        LegacyStorageMigration.migrate(context, config);
        assertEquals(dataAfter, snapshot(DATA_PREFS));
        assertEquals(keysAfter, snapshot(KEY_PREFS));
        assertEquals(markersAfter, snapshot(CONFIG_PREFS));

        FlutterSecureStorage storage = openStorage();
        assertReadable(storage, expected);
        assertReadable(openStorage(), expected);
        write(storage, "after_upgrade", "synthetic value written by v11");
        Map<String, String> withNewValue = new LinkedHashMap<>(expected);
        withNewValue.put("after_upgrade", "synthetic value written by v11");
        flushPreferences();
        assertReadable(openStorage(), withNewValue);
    }

    private void assertCurrentState() throws Exception {
        assertEquals("RSA_ECB_OAEPwithSHA_256andMGF1Padding",
                preferences(CONFIG_PREFS).getString(KEY_ALGORITHM, null));
        assertEquals("AES_GCM_NoPadding",
                preferences(CONFIG_PREFS).getString(STORAGE_ALGORITHM, null));
        assertTrue(preferences(KEY_PREFS).contains(CURRENT_GCM_WRAPPED_KEY));
        assertTrue(keyStore().containsAlias(OAEP_ALIAS));
        assertTrue(snapshot(JOURNAL_PREFS).isEmpty());
    }

    private FlutterSecureStorage openStorage() throws Exception {
        FlutterSecureStorage storage = new FlutterSecureStorage(context);
        LegacyStorageMigrationInstrumentedTest.<Void>awaitCallback(
                callback -> storage.initialize(config, callback));
        return storage;
    }

    private void assertReadable(FlutterSecureStorage storage, Map<String, String> expected)
            throws Exception {
        for (Map.Entry<String, String> entry : expected.entrySet()) {
            assertTrue(storage.containsKey(storage.addPrefixToKey(entry.getKey())));
            assertEquals(entry.getValue(), LegacyStorageMigrationInstrumentedTest.<String>awaitCallback(
                    callback -> storage.read(storage.addPrefixToKey(entry.getKey()), callback)));
        }
        assertEquals(expected, LegacyStorageMigrationInstrumentedTest
                .<Map<String, String>>awaitCallback(storage::readAll));
    }

    private void write(FlutterSecureStorage storage, String key, String value) throws Exception {
        LegacyStorageMigrationInstrumentedTest.<Void>awaitCallback(
                callback -> storage.write(storage.addPrefixToKey(key), value, callback));
    }

    private void seedEncryptedPreferences(Map<String, String> values) throws Exception {
        DeterministicAeadConfig.register();
        AeadConfig.register();
        DeterministicAead keys = new AndroidKeysetManager.Builder()
                .withSharedPref(context, KEYSET, DATA_PREFS)
                .withKeyTemplate(KeyTemplates.get("AES256_SIV"))
                .withMasterKeyUri("android-keystore://" + MASTER_ALIAS).build()
                .getKeysetHandle().getPrimitive(RegistryConfiguration.get(), DeterministicAead.class);
        Aead data = new AndroidKeysetManager.Builder()
                .withSharedPref(context, VALUE_KEYSET, DATA_PREFS)
                .withKeyTemplate(KeyTemplates.get("AES256_GCM"))
                .withMasterKeyUri("android-keystore://" + MASTER_ALIAS).build()
                .getKeysetHandle().getPrimitive(RegistryConfiguration.get(), Aead.class);
        assertTrue("Fixture requires a real AndroidKeyStore master key",
                keyStore().containsAlias(MASTER_ALIAS));
        for (String name : new String[]{KEYSET, VALUE_KEYSET}) {
            assertFalse("Fixture keyset must be encrypted by the AndroidKeyStore master key",
                    EncryptedKeyset.parseFrom(Hex.decode(preferences(DATA_PREFS)
                            .getString(name, ""))).getEncryptedKeyset().isEmpty());
        }
        SharedPreferences.Editor editor = preferences(DATA_PREFS).edit();
        for (Map.Entry<String, String> entry : values.entrySet()) {
            String encryptedKey = Base64.encodeToString(keys.encryptDeterministically(
                    prefixed(entry.getKey()).getBytes(StandardCharsets.UTF_8),
                    DATA_PREFS.getBytes(StandardCharsets.UTF_8)), Base64.DEFAULT);
            byte[] utf8 = entry.getValue().getBytes(StandardCharsets.UTF_8);
            byte[] typedString = ByteBuffer.allocate(8 + utf8.length)
                    .putInt(0).putInt(utf8.length).put(utf8).array();
            editor.putString(encryptedKey, Base64.encodeToString(data.encrypt(typedString,
                    encryptedKey.getBytes(StandardCharsets.UTF_8)), Base64.DEFAULT));
        }
        assertTrue(editor.commit());
    }

    private void seedRsaPkcs1(Map<String, String> values, boolean gcm) throws Exception {
        Calendar start = Calendar.getInstance();
        start.add(Calendar.DAY_OF_YEAR, -1);
        Calendar end = Calendar.getInstance();
        end.add(Calendar.YEAR, 1);
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA", "AndroidKeyStore");
        generator.initialize(new KeyGenParameterSpec.Builder(PKCS1_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(2048)
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setBlockModes(KeyProperties.BLOCK_MODE_ECB)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_PKCS1)
                .setCertificateSubject(new X500Principal("CN=Synthetic legacy migration fixture"))
                .setCertificateSerialNumber(BigInteger.ONE)
                .setCertificateNotBefore(start.getTime())
                .setCertificateNotAfter(end.getTime())
                .build());
        KeyPair pair = generator.generateKeyPair();
        byte[] aesBytes = new byte[16];
        new SecureRandom().nextBytes(aesBytes);
        SecretKeySpec aes = new SecretKeySpec(aesBytes, "AES");
        Cipher wrapper = Cipher.getInstance("RSA/ECB/PKCS1Padding", "AndroidKeyStoreBCWorkaround");
        wrapper.init(Cipher.WRAP_MODE, pair.getPublic());
        assertTrue(preferences(KEY_PREFS).edit().putString(
                gcm ? V9_GCM_WRAPPED_KEY : CBC_WRAPPED_KEY,
                Base64.encodeToString(wrapper.wrap(aes), Base64.DEFAULT)).commit());
        SharedPreferences.Editor editor = preferences(DATA_PREFS).edit();
        if (gcm) {
            editor.putString(KEY_ALGORITHM, "RSA_ECB_PKCS1Padding");
            editor.putString(STORAGE_ALGORITHM, "AES_GCM_NoPadding");
        }
        for (Map.Entry<String, String> entry : values.entrySet()) {
            byte[] iv = new byte[gcm ? 12 : 16];
            new SecureRandom().nextBytes(iv);
            Cipher cipher = Cipher.getInstance(gcm ? "AES/GCM/NoPadding" : "AES/CBC/PKCS5Padding");
            if (gcm) cipher.init(Cipher.ENCRYPT_MODE, aes, new GCMParameterSpec(128, iv));
            else cipher.init(Cipher.ENCRYPT_MODE, aes, new IvParameterSpec(iv));
            byte[] encrypted = cipher.doFinal(entry.getValue().getBytes(StandardCharsets.UTF_8));
            editor.putString(prefixed(entry.getKey()), Base64.encodeToString(
                    ByteBuffer.allocate(iv.length + encrypted.length).put(iv).put(encrypted).array(),
                    Base64.DEFAULT));
        }
        assertTrue(editor.commit());
    }

    private static Map<String, String> fixtureValues() {
        Map<String, String> result = new LinkedHashMap<>();
        result.put("plain", "synthetic-only credential");
        result.put("empty", "");
        result.put("unicode", "架空の値 🔐 café\nsecond line");
        return result;
    }

    private static String prefixed(String key) { return PREFIX + "_" + key; }

    private SharedPreferences preferences(String name) {
        return context.getSharedPreferences(name, Context.MODE_PRIVATE);
    }

    private Map<String, ?> snapshot(String name) {
        return new HashMap<>(preferences(name).getAll());
    }

    private void flushPreferences() {
        // Commit waits for writes enqueued by upstream apply() without altering values.
        assertTrue(preferences(DATA_PREFS).edit().commit());
        assertTrue(preferences(KEY_PREFS).edit().commit());
        assertTrue(preferences(CONFIG_PREFS).edit().commit());
    }

    private void clearSyntheticState() throws Exception {
        for (String name : new String[]{DATA_PREFS, KEY_PREFS, CONFIG_PREFS,
                GLOBAL_CONFIG_PREFS, JOURNAL_PREFS}) {
            assertTrue(preferences(name).edit().clear().commit());
        }
        KeyStore keys = keyStore();
        for (String alias : new String[]{PKCS1_ALIAS, OAEP_ALIAS, MASTER_ALIAS}) {
            if (keys.containsAlias(alias)) keys.deleteEntry(alias);
        }
    }

    private static KeyStore keyStore() throws Exception {
        KeyStore result = KeyStore.getInstance("AndroidKeyStore");
        result.load(null);
        return result;
    }

    private interface Operation<T> { void start(SecurePreferencesCallback<T> callback); }

    private static void awaitFailure(Operation<Void> operation) throws Exception {
        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<Exception> error = new AtomicReference<>();
        operation.start(new SecurePreferencesCallback<Void>() {
            @Override
            public void onSuccess(Void result) { latch.countDown(); }
            @Override
            public void onError(Exception failure) { error.set(failure); latch.countDown(); }
        });
        assertTrue("Storage failure callback timed out", latch.await(15, TimeUnit.SECONDS));
        assertNotNull("Corruption must be reported through the real initialization callback", error.get());
    }

    private static <T> T awaitCallback(Operation<T> operation) throws Exception {
        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<T> value = new AtomicReference<>();
        AtomicReference<Exception> error = new AtomicReference<>();
        operation.start(new SecurePreferencesCallback<T>() {
            @Override
            public void onSuccess(T result) { value.set(result); latch.countDown(); }
            @Override
            public void onError(Exception failure) { error.set(failure); latch.countDown(); }
        });
        assertTrue("Storage callback timed out", latch.await(15, TimeUnit.SECONDS));
        if (error.get() != null) throw new AssertionError("Storage callback failed", error.get());
        return value.get();
    }
}
