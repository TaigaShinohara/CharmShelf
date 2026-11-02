# flutter_image_compress_common ローカルパッチ

- 基準版: `1.1.1`
- 公式archive: https://pub.dev/api/archives/flutter_image_compress_common-1.1.1.tar.gz
- Archive SHA-256: `76869e4d5f3d65f3431e7edff0b2d8ad1eea68b49c6a37772fdb1ae6016da9ed`（取得時照合済み）

## 保持する差分

SwiftPMのMantle 2.2.0、SDWebImage 5.21.7、ローカルSDWebImageWebPCoder 0.15.0とそのlibwebp 1.5.0の固定を維持する。上流1.1.1のnative/Dart/Android実装へ更新し、iOSヘッダー配置を上流のinclude構成へ合わせる。上流で不要になった旧SYPictureMetadata実装は含めない。

アプリ内の権限・署名・保存形式は変更しない。ライセンスは同梱の`LICENSE`を正とする。SwiftPM manifest解析、Android debug / Release(R8)、iOS no-codesign、関連runtime回帰を統合後に検証する。実機の権限要求や外部ファイル表示は別途確認する。
