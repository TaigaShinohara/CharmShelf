# 通知22.3.3の互換性パッチ

出典: https://pub.dev/api/packages/flutter_local_notifications/versions/22.3.3
Archive: https://pub.dev/api/archives/flutter_local_notifications-22.3.3.tar.gz
SHA-256: `fd5fc8966a8b34337ac182dc394f3506139b69d8138d4e9e174a13d6468adcd4`

公式安定版のDart API、保存形式、Privacy、LICENSEを保持する。example・画像は含めない。既存のAndroid単体テスト2本と、新しいDST回帰5ケースを含む公式テストを保持する。pubspecのLinux依存は同一graphの `../flutter_local_notifications_linux` 8.0.2を参照し、iOS/macOSのPackage.swiftでFlutterFrameworkへの重複依存を除く。Flutter 3.47.8が生成するFlutterGeneratedPluginSwiftPackageから一度だけFlutterを供給する既存構成を維持する。上流原版ハッシュと移植理由・適用後ハッシュは `scripts/maintenance/path_override_upstream_hashes.json` に記録する。

iOSの`buildUserDict`は元から可変辞書を返すため、private戻り型を`NSMutableDictionary`へ揃える。同じinstanceへのdismissIsolate追記とuserInfoへの格納契約を保つ。非推奨Alert optionはdeployment minimumが14未満のときだけcompileし、package最低13でのpresentAlert fallbackを残す。iOS14以降のpresentBanner/presentList個別設定、Sound/Badge、完了callbackは変えない。警告disableや生のoption値への置換は使わない。

timezone 0.11.2/platform_interface 12.2/Windows 3.1.1以上を同一graphで維持する。iOS最低13、Android最低24はアプリの既存下限内。通知設定・権限要求・callback方針はアプリ側で変更しない。22.3.2のiOS27 badge修正に加え、22.3.3はAndroidの繰り返し予約がDSTのgapを越えた後も元の壁時計時刻を保つ修正を採用する。DST overlapと通常日を含む公式5ケースは `NextFireDateMatchingDateTimeComponentsTest` に保持し、`:flutter_local_notifications:testDebugUnitTest` で実行する。Appleの公式ソースとmanifestは22.3.2と同一で、既存3パッチを維持する。

更新時は上流runtime一致検査、アプリ通知・timezone回帰、Linux DBus wire-valueと上流manager/storageテスト、SwiftPM単一link・native buildを確認する。実OS上の通知表示・タップ・バックグラウンド動作は別検証とする。
