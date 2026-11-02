# CharmShelf セットアップガイド

[README](../README.md) · [English overview](../README.en.md)

公開ソースからDebug版を開発・検証する手順です。所有者のアカウント、APIキー、1Password、ストア配布用の証明書は必要ありません。初回はFlutter・各プラットフォームのSDK・依存関係をダウンロードするため、ネットワーク接続が必要です。

## 必要なもの

- Flutter **3.47.9** と同梱Dart。`pubspec.yaml` の `environment.flutter` が正本です。任意の場所にインストールし、その `bin` をPATHに追加してください。
- Android: JDK 17、Android SDK、platform-tools。必要なcompile SDKは `android/app/build.gradle.kts` を確認してください。SDKパスはAndroid StudioまたはFlutterで設定します。ローカルの `android/local.properties` はコミットしません。
- iOSシミュレーター: macOS、Xcode、必要なシミュレーターruntime、Xcode Command Line Tools。Xcodeの初回設定は本人が行い、`flutter doctor -v` の指摘を解消してください。
- 準備スクリプト・検証用のPython 3.11以降、Git、Bash。

ビルド前に実行中のビルド、メモリ、空きディスクを確認してください。Gradleの上限は3072 MB・2 workersです。同時に複数のビルドを起動しないでください。

## 初回準備

リポジトリのルートで実行します。

```sh
flutter --version
flutter doctor -v
bash scripts/setup_dev.sh
```

`setup_dev.sh` はFlutterの版確認、依存取得、同梱済みIsarホストライブラリの配置、設定・モデル・翻訳の生成をまとめて行います。Isarにはnativeライブラリが必要なため、`flutter pub get` だけでホストテストの準備が完了するとは限りません。スクリプトが未対応のホストOSや同梱ファイルの不足で停止した場合は、エラーを解消して再実行してください。別の版のnativeバイナリで代用しないでください。

`flutter pub get` で意図せず `pubspec.lock` が変わった場合は差分を確認します。問題を回避するための一括依存更新は行わないでください。

## Android Debug

```sh
flutter devices
flutter build apk --debug
```

端末・エミュレーターで起動する場合は、`flutter devices` に表示されたIDで `DEVICE_ID` を置き換えます。USBデバッグの有効化や端末側の接続許可は本人が行います。

```sh
flutter run -d DEVICE_ID
```

公開版のapplicationIdは旧配布版と分離されています。Debugビルドは開発用の署名を使い、既存配布版の署名鍵を要求しません。実行・アンインストール・データ消去の対象は必ず端末で確認してください。

## iOSシミュレーター

Xcodeで必要なシミュレーターruntimeをインストールし、シミュレーターを起動します。

```sh
flutter devices
flutter build ios --simulator --debug
flutter run -d SIMULATOR_ID
```

`SIMULATOR_ID` は一覧のIDへ置き換えます。シミュレーター用ビルドにApp Store用の証明書やプロビジョニングプロファイルは不要です。

iOSのnative依存はSwift Package Managerを使用します。CocoaPodsを追加したり、`pod install` で解決を試みたりしないでください。nativeパッケージの構成は次で確認できます。

```sh
python3 scripts/maintenance/check_ios_swift_packages.py
```

iOS実機の署名は各自のApple開発環境で設定します。旧配布版のチーム・証明書・プロファイルを流用しないでください。ストア配布はこのセットアップ手順の範囲に含みません。

## 日常の生成手順

アプリ設定を変えた場合:

```sh
dart run scripts/update_config.dart
```

モデルやRiverpod providerを変えた場合:

```sh
dart run build_runner build
```

翻訳は `lib/l10n_src/ja/` と `lib/l10n_src/en/` を編集します。`lib/l10n/` の結合済みARBや生成Dartを直接編集しません。

```sh
dart run scripts/merge_l10n.dart
flutter gen-l10n
dart run scripts/check_l10n_consistency.dart
```

## 検証

```sh
flutter analyze
flutter test --exclude-tags golden
dart run scripts/check_l10n_consistency.dart
dart run scripts/maintenance/check_audit_patterns.dart
python3 scripts/maintenance/check_private_content.py --sources-only
```

標準のCIと上記コマンドは、描画環境に依存する `golden` タグの画像比較を除外します。UI変更時は対象環境で `flutter test --tags golden` を追加し、差分画像を確認してください。基準画像の一括更新を成功の根拠にしないでください。

変更した機能に関連する検証を優先し、native処理は対象端末でも確認してください。ホストテストだけでファイルアクセス権限、生体認証、音声出力、バックアップ先の挙動がすべて確認されたことにはなりません。

出力を保存して要点だけ確認したい場合:

```sh
bash scripts/quiet_check.sh flutter analyze
```

## 名前・対応範囲・配布

- アプリ表示名はCharmShelf、内部Dartパッケージ名は `private_shelf` です。内部名の一括置換は不要です。
- 主対象はAndroidとiOSです。macOS・Windows・Linux・Webのファイルも含みますが、公開版の全機能・全OS検証が完了したという意味ではありません。
- 署名・ストアAPI・配布の補助スクリプトは通常開発には不要です。[認証と配布の境界](../auth/README.md)を確認してください。
- ローカルパッチの変更時は[依存パッチ台帳](DEPENDENCY_OVERRIDES.md)と元ライセンス・由来情報を維持してください。

## Optional isolated local settings (macOS/Linux)

If a machine has stale global Flutter/JDK settings, use `python3 scripts/flutter_local.py build apk --debug` instead of changing shared configuration. It uses a locally provisioned SDK in `build/toolchains/flutter-3.47.9` when available, otherwise Flutter from PATH; on macOS it can select an installed JDK 17. An inherited JAVA_HOME is used only if its Java binary can execute; an unusable inherited value falls back to the system JDK without changing the parent environment. You may pass `--java-home /path/to/jdk` or `--android-sdk /path/to/sdk` before the Flutter command. Configuration exists only in a temporary process directory. If a legacy home `.flutter_settings` file prevents isolation, the wrapper stops without modifying it. SDKs and generated local settings are not committed.

The optional Python regression suite for the distribution wrappers requires `zsh` (on Ubuntu: install the `zsh` package). Public CI installs it explicitly. This is not a signing credential and normal Flutter app development does not run distribution wrappers.
