# Flutter Gradle configuration-cache patch

基準はプロジェクトで固定するFlutter 3.47.8（framework revision `737ba8f885`）のSDKソース。共有SDKは変更しない。`build.gradle.kts`の`expectedSources`に6つの上流ソースと上流build設定のSHA-256を固定し、不一致なら停止する。

## 2026-10-22のrebase

SDKのGradle/AGP/Kotlin最低・警告版、NdkVersion表示、ABI別versionCodeの明示上書き対応、現行Android extensionアクセスを取り込んだ。4つのtask系上流ソースは旧基準から変更なし。SDK由来の依存版・ライセンスは保持する。

ローカル差分はConfiguration Cacheが禁止する実行時のProject/Variant捕捉を取り除くためのもの。注入したObjectFactory/ProjectLayout/ExecOperationsと、構成時に確定した最小SDK・APKコピー値を使う。最低SDK違反は引き続き例外として失敗させる。

統合後は通常Androidビルドに加え、`--configuration-cache`厳格検査の保存・再利用、Dartソース変更の再ビルド、最低SDK違反、APKコピーを検証する。SDK guardの一致とビルド成功・cache再利用は別々の証拠として記録する。
