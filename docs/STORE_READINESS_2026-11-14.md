# CharmShelf ストア審査準備レポート（store_review_readiness）

- 確認日: 2026-11-14
- 対象ビルド: main `c19b640` / versionName 1.0.12 / versionCode 108 / パッケージ `com.tsmusic.privateshelf.opensource`
- 対象ストア: Google Play（Android）と Apple App Store（iOS）の両方（本人の選択 2026-11-14）
- 総合判定: **両ストアとも「直せば提出可能」**。アプリ側の技術土台は揃っている。不足は主に「提出用ビルド（署名）」「プライバシーポリシーの公開URL」「ストア側の申告・登録」の3系統。

## アプリの実態（実物確認済み）

- ローカルファーストのメディアライブラリ。開発者サーバーなし、アカウント作成なし、ログインなし。
- 解析・広告・クラッシュ送信SDKなし（pubspec 全依存を確認。Firebase / Analytics / Sentry / AdMob 等なし）。クラッシュログは端末内のみで、送信はユーザー操作時のみ。
- 課金: 「支援購入（チップ）」のみ。`lib/features/tip/` が in_app_purchase（Play Billing / StoreKit）を使用。デジタル商品の外部決済誘導なし。
- Android 実権限（提出APKで確認）: INTERNET / CAMERA / USE_BIOMETRIC / POST_NOTIFICATIONS / RECEIVE_BOOT_COMPLETED / VIBRATE / ACCESS_NETWORK_STATE / READ・WRITE_EXTERNAL_STORAGE（maxSdk 29）/ WAKE_LOCK / FOREGROUND_SERVICE / FOREGROUND_SERVICE_MEDIA_PLAYBACK / BILLING / USE_FINGERPRINT。
  - READ_MEDIA_IMAGES / READ_MEDIA_VIDEO は**要求していない**（取り込みは SAF / ピッカー）。MANAGE_EXTERNAL_STORAGE は除去宣言済み。
  - targetSdk 36 / minSdk 24 / 64bit ネイティブライブラリ 16KB アライン確認済み（check_android_bundle 合格）。
- iOS: 権限の理由文（カメラ・マイク・写真・Face ID）あり、PrivacyInfo.xcprivacy 同梱あり、deployment target iOS 15.0。
- プライバシーポリシー: 原稿が `docs/PRIVACY_POLICY.md` にある（最終更新 2026-10-02、ただし「公開前の更新案」表記）。運営主体 Private Shelf Project、窓口 deeple+charmshelfstaff@inkboxmail.com。**公開URLはまだ無い**。
- リリース署名: リポジトリ設計では Mac + 1Password スクリプト（`scripts/android_signing_1password.py`）経由が必須。このVMで作ったAPKはデバッグ署名で提出には使えない。

## Google Play 判定: 直せば提出可能

### 適合している点（根拠つき）
- 対象API: 2026-08-31 以降、新規・更新は API 36 以上が必須（Play Console Help 公式）。実ビルドは targetSdk 36 で適合。
- 16KB ページサイズ: API 35+ で必須。実APKでアライン確認済み。
- 写真・動画権限ポリシー: READ_MEDIA_* を使わないため用途宣言は不要。
- アカウント削除導線: アカウント作成がないため対象外。審査用アカウントも不要。

### 提出前に必須で直す・用意する項目
| # | 項目 | 担当 | 完了条件 |
|---|---|---|---|
| P1 | リリース署名付き **AAB** を Mac で作成（現状デバッグAPKのみ）。Play App Signing へ登録 | 開発者（Mac） | 署名済みAABが Play Console にアップロードできる状態 |
| P2 | プライバシーポリシーの**公開URL**（原稿は「公開前の更新案」のため確定＋Web公開） | パソパソ準備／本人が公開先を決定 | URLを開いて本文が読める |
| P3 | フォアグラウンドサービス申告（mediaPlayback）: Play Console の申告フォームに用途説明＋**デモ動画**（公式ポリシー: 対象API 14+ では Console 申告と説明・デモ動画が必要） | パソパソが文案と動画を用意 | 申告が下書き保存できる状態 |
| P4 | 支援購入（チップ）の商品を Play Console に作成し、課金申告を実態と一致させる | 本人（Console操作）＋パソパソ下準備 | 商品が有効化でき、アプリ側 product ID と一致 |
| P5 | Data safety フォーム回答: 「データ収集・共有なし」を基本線に、ストア取引（Google Play が処理）と端末内処理の扱いを最終確認して提出 | パソパソが下書き | 申告下書きが完成 |
| P6 | コンテンツレーティング（IARC）、ターゲットオーディエンス（子ども向けではない設定）、広告なし申告 | パソパソ下書き／本人が Console で回答 | 各申告が完了状態 |
| P7 | アプリ枠（CharmShelf）の作成とパッケージ名の確保 | 本人（Co
...[truncated 3396 chars]