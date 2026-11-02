# flutter_secure_storage 11.2.0 — TagShelf旧形式移行

上流: https://pub.dev/packages/flutter_secure_storage/versions/11.2.0

配布archive: https://pub.dev/api/archives/flutter_secure_storage-11.2.0.tar.gz

archive SHA-256: `d4e1fb6b2cb524868929e78dc0282fa000554b22060fb53789dc481c9fc95bb8`。
旧形式の参照元10.3.4 archive SHA-256: `fe638107c5f69119156ada2db5a57734385fac3f64430bd7252a00d3ead2ca4b`。

`UPSTREAM_SHA256.json` は上流11.2.0のDart・Androidソースと設定のSHA-256を保存する。`PATCHES.json` は変更理由、元ハッシュ、採用ハッシュ、新規ファイルを記録する。上流のLICENSEを維持する。

## 変更範囲

- `pubspec.yaml` のworkspace解決指定を外し、既存アプリからpath依存として解決する。
- Android `FlutterSecureStorage.initialize` の最初に移行gateを挿入する。11が旧データを解釈・初期化する前に完了させ、失敗時はcallback errorとして返す。
- initialize成功前にwrapped keyとcurrent algorithm markerを同期commitする。上流11が`migrateWithBackup:true`の新規storeでmarkerを書かないため、初回保存後の再起動が旧形式と誤判定されることを防ぐ。
- `LegacyStorageMigration` は旧EncryptedSharedPreferencesのTink AES-SIV/AES-GCM、RSA-PKCS1/OAEPで包まれたAESキー、AES-CBC/GCMの既存wire formatを読取専用で解釈する。新規保存は11.2.0の標準RSA-OAEP/AES-GCM実装を使う。旧KeyStore鍵は生成・置換・削除しない。
- 形式の根拠は[10.3.4](https://pub.dev/packages/flutter_secure_storage/versions/10.3.4)の`crypto/EncryptedSharedPreferences.java`、`ciphers/KeyCipherImplementationRSA18.java`、`ciphers/KeyCipherImplementationRSAOAEP.java`、`ciphers/StorageCipherImplementationAES18.java`、`ciphers/StorageCipherImplementationGCM.java`。cipher実装は同梱BSD 3-Clause、AndroidX由来のESP形式はApache 2.0の権利表示を保持する（`THIRD_PARTY_NOTICES.md`）。
- 旧暗号文・wrapped key・algorithm markerのsnapshotを、アプリ専用SharedPreferences journalへ同期commitしてから移行する。平文はメモリ内だけに置き、全件復号・新暗号文の全件round-trip確認後にdataとmarkerをcommitする。
- data/key/marker保存途中のエラーやprocess停止時は暗号文journalから元のdata/key/markerを復元して再実行する。復元できない場合も11の読取へ進まず、journalを保持する。全保存完了後のjournal消去失敗はエラーを返しつつ整合した新形式を保持し、journalがdiskに残った場合は次回復元・再試行する。元KeyStore鍵は保持する。
- アプリ側は`resetOnError:false`と`migrateWithBackup:true`を指定する。未知の形式、鍵不足、復号失敗、commit失敗を空データへ変換しない。
- iOS/macOS実装はhosted `flutter_secure_storage_darwin ^0.4.0`を継続する。0.4.3のSwiftPM manifestはFlutterFrameworkを追加せず、既存の単一リンク構成を保持する。

## 適用範囲と検証

TagShelfの既存default non-biometric storeを移行対象とする。旧版は`encryptedSharedPreferences:true`を指定し、2026-08-27の`9829c41f`から10系へ移行している。同じstoreに異なるkey prefixが共存する未採用構成は、共有wrapped keyやmarkerを変更する前に拒否する。将来異なるcipherやbiometric storeを導入するときは、その移行条件を別途検証する。

- `LegacyMigrationTransactionTest`: journal失敗、data/key/markerの各commit直後の例外・process停止、復元失敗、cleanup失敗、再試行、current store非変更。
- `LegacyStorageMigrationTest`: 合成RSA-PKCS1/AES-CBCと実Tink primitiveによるESP wire-formatから、実11 read実装への再オープン、namespace associated data不一致、破損値の失敗、journalの型保持。
- `LegacyStorageMigrationInstrumentedTest`: 明示flag・専用emulator・独立test package/UID確認後に、実Android Keystoreの合成ESP/PKCS1-CBC/v9 GCMを移行して11で読み直す。初回write/reopen、破損・master key欠落時の保持/再試行も検査する。製品アプリのcontext/dataは使用しない。
- テストは合成データだけを使用する。実ユーザーのKeyStore、PIN、暗号文を取得しない。端末のKeystoreを用いる実更新経路の検証は別途必要。

実行結果はrootの依存更新記録へ記載する。
