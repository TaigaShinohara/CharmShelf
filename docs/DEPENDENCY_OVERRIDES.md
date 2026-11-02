# ローカル依存パッチ監査台帳

採用済みの直接依存パッチは `dependencies` のpath参照を正本とし、間接依存パッチは `dependency_overrides` で参照します。新しい公式版へ更新する際は、ローカル版との差分を確認し、Android/iOSビルドと全テストが通れば対応するpath参照・overrideを公式版へ戻します。

| パッケージ | 基準バージョン | 主な対象 | fork理由・復帰条件 |
|---|---:|---|---|
| isar_flutter_libs | 3.1.0+1 | Android/iOS/Desktop | 現行Flutter・ビルドツール、iOS SwiftPM互換、およびAndroid 16KB page size対応。公式版で同等修正後に復帰 |
| shared_storage | 0.8.1 | Android | namespace/AGP互換。公式版がAGP 8以降へ対応後に復帰 |
| audio_service | 0.18.19 | Android/iOS | 現行プラットフォームビルド互換。公式版検証後に復帰 |
| device_info_plus | 13.3.0 | Android/iOS/Desktop/Web | 現行ビルド設定互換、WindowsのWin32Result/bool/文字列・registry3 API対応。公式版検証後に復帰 |
| android_file_picker | 2.1.1 | Android | parentは公式file_picker13.3.0を採用。アプリ独自cancelPendingRequestと、キャンセル後の旧ActivityResult・IO完了を新しい選択へ混入させない識別を保持。公式実装が同等契約を持ち合成回帰と実機を検証後に復帰 |
| flutter_image_compress_common | 1.1.1 | 共通 | SwiftPMでMantle 2.2.0、SDWebImage 5.21.7、ローカルSDWebImageWebPCoder 0.15.0を固定。公式版で同等構成をRelease検証後に復帰 |
| flutter_local_notifications | 22.3.3 | Android/iOS/macOS/Linux/Windows/Web | 公式runtimeを保持し、Linux8.0.2へのpathとFlutterFramework単一リンクのmanifest差分を維持。platform_interface12/timezone0.11を同一graphで検証。単一リンク構成を公式版で検証後に復帰 |
| flutter_local_notifications_linux | 8.0.2 | Linux | DBus0.8の制約は公式対応済み、runtime/pubspecも原版一致。wire-value回帰を保持し、通知parentと同じgraphを候補計算へ渡すためpath参照を維持 |
| in_app_review | 2.0.12 | Android/iOS | 現行ストアSDK互換。公式版検証後に復帰 |
| image_picker_ios | 0.8.13+13 | iOS | 公式Swift/ObjCの2target SwiftPM構成を保持し、non-frozen camera enumの未知値だけrearへfallbackする。既知front/rearと権限・公開APIは維持。上流に同等対応が入ったら復帰 |
| local_auth_darwin | 2.0.5 | iOS/macOS | 現行Xcode/認証API互換。公式版検証後に復帰 |
| open_file_ios | 1.1.0 | iOS | 公式runtimeへrebaseし、FlutterFramework単一リンクのSwiftPM構成を維持。公式版で同等構成を検証後に復帰 |
| permission_handler_apple | 9.6.4 | iOS/macOS | 公式runtimeへrebaseし、SwiftPMのcamera/photos/notificationsのみ許可する既存構成を維持。権限範囲と単一リンクを公式版で検証後に復帰 |
| downloadsfolder | 2.0.0-pre.1 | iOS/Android/Desktop | iOS SwiftPMマニフェスト追加。公式版に同等マニフェストが入り、Android/Dart差分なしとReleaseで検証できたら復帰 |
| secure_application | 4.1.0 | iOS/Android/Web/Windows | iOS SwiftPM化、UISceneごとの非active保護、複数window解除へ移行。AndroidはAGP 8.13のAAR metadata検査に合わせcompile SDK 36を使用（min/target SDKとruntimeは維持）。公式版で同等挙動をSimulator/実機で検証できたら復帰 |
| video_thumbnail | 0.5.6 | iOS/Android | iOS SwiftPMマニフェスト追加。AndroidはAGP 8.13のAAR metadata検査に合わせcompile SDK 36を使用（min/target SDKとruntimeは維持）。公式版に同等対応が入り、動画サムネイルをReleaseで検証できたら復帰 |
| share_plus | 13.3.1 | Android/iOS/Desktop/Web | 現行ビルド設定互換、WindowsのRtlGetVersion/NTSTATUS/Arenaと登録分岐をwin32 6対応。公式版検証後に復帰 |
| wakelock_plus | 1.8.2 | Linux/Windows（他platform原版保持） | DBus 0.8系とpackage_info_plus 10系/win32 6系に統一、Windowsのtyped EXECUTION_STATE対応。公式版で同じ依存graphとInhibit/Close互換を検証後に復帰 |
| isar_generator | 3.1.0+1 | 開発時コード生成 | analyzer14/build4/source_gen4へ接続する3ファイルのみ移植。Isar3の保存形式・native・14生成テンプレートを維持し、全7モデルの生成トークン一致と合成DBを検証。公式生成器が同等toolchainに対応後に復帰 |
| flutter_secure_storage | 11.2.0 | Android（他OSは公式実装） | 旧ESP/RSA-AES形式の読取と暗号化journalを用いた再試行可能な移行を追加。データ消去によるエラー回避を禁止。詳細と検証は移行記録を参照 |


現行の採用graphは [pubspec.yaml](../pubspec.yaml) と [pubspec.lock](../pubspec.lock) を正本とします。各パッチの変更箇所と上流へ戻す条件は、対応する `patches/` 内の `README.patch*` とライセンスを確認してください。

file_pickerは公式13.3.0のfederated実装を採用します。未使用の旧file_pickerパッチとDKImagePickerController・DKPhotoGallery・SwiftyGifソースは公開スナップショットから除外しています。

## 更新時の確認

- Flutterは `pubspec.yaml` で固定した3.47.9を使用し、変更する依存と必要な推移依存だけを更新します。
- 上流の版、差分、取得元、hash、ライセンス・著作権表示を保持します。適用条件と対応platformを各パッチへ記録してください。
- モデル生成・静的解析・関連テスト・対象platformのビルドを確認します。hostで検証した結果と実OS・実端末での結果を区別してください。
- iOSのSwiftPM構成と権限を変更する際は、manifest、Info.plist、FlutterFrameworkのリンク構成をまとめて確認します。
- 公式版へ戻す際は、既存パッチの動作契約と依存graphを比較し、復帰理由と未検証範囲を記録します。

上流ソースとの対応とIsar生成器の互換性は、次の既存検査を利用できます。

```sh
python3 scripts/maintenance/check_path_override_upstream.py
python3 scripts/maintenance/check_isar_codegen_compatibility.py
```

[第三者ライセンス一覧](../THIRD_PARTY_NOTICES.md)とアプリ内の完全なnotice snapshotも更新してください。[native由来情報](NATIVE_PROVENANCE.md)にはIsar・PDFiumの取得元とnotice再生成手順を記載しています。Isar Androidバイナリ固有の変更は[16KB対応の記録](../patches/isar_flutter_libs/ANDROID_16KB_BUILD.md)を確認してください。

## Flutter Gradleプラグイン

`android/flutter_gradle/` はConfiguration Cacheを明示指定した場合の専用パッチです。通常のビルドはSDKのプラグインを使います。[パッチの説明](../android/flutter_gradle/README.patch.md)と同ディレクトリのLICENSEを保持し、SDK更新時は元ソースhash・最低SDK検査・APKコピー・cache保存と再利用を確認してください。共有Flutter SDKは変更しません。

## Public PDF reader

The public fork uses MIT-licensed pdfrx instead of the previous proprietary PDF SDK. External links are confirmed in the application and limited to http, https, mailto and tel. Internal document destinations remain in the viewer. Original files are never deleted by PDF rendering.
