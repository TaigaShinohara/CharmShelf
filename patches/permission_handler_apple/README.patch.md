# permission_handler_apple ローカルパッチ

- 基準版: `9.6.4`
- 公式archive: https://pub.dev/api/archives/permission_handler_apple-9.6.4.tar.gz
- Archive SHA-256: `b69e6b8300f9584af5ab81b41cdaa544e1b45e6fca0a30b0f9a9a120d90fc8a5`（取得時照合済み）

9.6.4の通知・critical alerts status/request非同期化を採用する。iOS27でシステム応答がmain queueへ配送されても、PermissionManagerは応答を待ってmain threadを停止せず、結果をmain queueへ返す。LocationAlwaysの未要求時判定修正も上流どおり保持するが、アプリの有効権限は増やさない。

## 保持する差分

SwiftPMの権限定義をプロジェクトの固定許可リストに限定する。上流の環境変数・Info.plist自動検出マニフェストは使用せず、既存の通知・カメラ・写真だけを有効にする。PrivacyInfo.xcprivacyは上流原版を保持する。上流モノレポのresolution: workspaceは独立path依存のため除去する。flavor選択CLIは含めない。

電話サービスの確認は、Package.swiftとpodspecの最低iOS 12.0で利用できる`serviceSubscriberCellularProviders`へ統一する。iOS 12未満だけの`subscriberCellularProvider`分岐を除去し、既存の単一SIM・複数SIMの判定と返値は維持する。`CTCarrier`を別の機能へ置き換える変更は含めない。

通知状態の`@available`は論理ANDの一部にせず、新しい共通mapper `permissionStatusFromSettings:` の独立したavailability条件で`UNAuthorizationStatusProvisional`を囲む。Denied・NotDetermined・Provisional・その他の状態の返値、上流の非同期completionと残された同期fallbackは維持する。同期fallbackはmain threadから呼ばないという上流契約を保持する。

## callback回帰

`test/ios/NotificationPermissionStrategyTests.swift` は公式archiveの `example/ios/RunnerTests/NotificationPermissionStrategyTests.swift` を変更せず保持する。これは未要求状態の専用iOS test hostでFlutter plugin経由のmain-thread非同期応答を確認するXCTestであり、このリポジトリのFlutterテストだけでは実行されない。

`python3 patches/permission_handler_apple/test/check_notification_callbacks.py` は実際の `NotificationPermissionStrategy.m` を変更せず、Foundation/dispatchと合成UIKit/UserNotificationsアダプタでコンパイルして実行する。設定応答をmain queueへ配送し、status5ケースとrequest7ケースで非blocking・状態mapping・callback一回・許可要求/remote登録の回数とoptionsを検査する。OSの権限API、Simulator、個人データ、許可UIは利用しない。main-queue待機への退行は20秒timeoutで失敗する。これはPermissionManager/Flutter経路や実OSの応答を検証したことにはならない。ビルド枠とリソースを確認してから、rootのquiet_check経由で直列実行する。

アプリ内の権限・署名・保存形式は変更しない。ライセンスは同梱の`LICENSE`を正とする。SwiftPM manifest解析、Android debug / Release(R8)、iOS no-codesign、関連runtime回帰を統合後に検証する。実機の権限要求や外部ファイル表示は別途確認する。
