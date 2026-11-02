# open_file_ios ローカルパッチ

- 基準版: `1.1.0`
- 公式archive: https://pub.dev/api/archives/open_file_ios-1.1.0.tar.gz
- Archive SHA-256: `0e3e67dcd12f69888128f533cacc092039627dd4f1d7a95a2826b814ae4ea8aa`（取得時照合済み）

## 保持する差分

SwiftPMの製品名・公開ヘッダーと上流のiOS13最小要件を保持する。Flutterはアプリで一度だけリンクするため、上流の存在しない../FlutterFrameworkローカルpackage参照を追加しない。

iPad判定はdeprecatedな`UI_USER_INTERFACE_IDIOM()`から、対応OSで同じ値を返す`UIDevice.currentDevice.userInterfaceIdiom`へ移す。popoverのanchor・表示方法・完了callbackは維持する。

アプリ内の権限・署名・保存形式は変更しない。ライセンスは同梱の`LICENSE`を正とする。SwiftPM manifest解析、Android debug / Release(R8)、iOS no-codesign、関連runtime回帰を統合後に検証する。実機の権限要求や外部ファイル表示は別途確認する。
