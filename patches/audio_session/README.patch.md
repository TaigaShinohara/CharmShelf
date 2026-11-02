# audio_session 0.2.4 のiOS互換性パッチ

- 基準版: `0.2.4`
- 公式メタデータ: https://pub.dev/api/packages/audio_session/versions/0.2.4
- 公式archive: https://pub.dev/api/archives/audio_session-0.2.4.tar.gz
- Archive SHA-256: `f9e7711a0e24ca8b40f5d7ac374c3c6e55016f3157912badd18199cdbbca5c4d`（公開メタデータと取得内容を照合）

公式版のDart、Android、iOS、macOS runtime、各manifest、LICENSEを保持する。`example/` と旧設定の `bak/` は含めない。上流のiOS最低12.0、macOS最低10.14、Swift tools 5.9を変更しない。iOSの `AUDIO_SESSION_MICROPHONE` は公式版どおり環境指定なしでは `0` のままとし、マイク権限要求を有効化しない。

変更対象はiOSの `DarwinAudioSession.m` の中断通知にある `wasSuspended` の取得処理だけ。iOS 14.5未満では既存の `AVAudioSessionInterruptionWasSuspendedKey` を保持し、14.5以上16未満では置換先の `AVAudioSessionInterruptionReasonKey` が存在する場合だけ `AppWasSuspended` と比較してBooleanへ変換する。欠落時は従来どおり `NSNull` を送る。AppleはiOS 16以降にsuspension理由の中断通知が発生しないと明記しているため、その範囲では欠落値を維持する。古いAPIはそのOSを配布対象に含む場合だけコンパイルする。

`onInterruptionEvent` のメソッド名・引数の順序と型、began/ended判定、shouldResume、Dartの公開型と上位ストリーム処理、audio sessionの設定・権限・他プラットフォームは変更しない。警告抑制や非推奨キーの文字列・数値への置換は行わない。

根拠はAppleの [旧wasSuspendedキー](https://developer.apple.com/documentation/avfaudio/avaudiosessioninterruptionwassuspendedkey)、[置換先reasonキー](https://developer.apple.com/documentation/avfaudio/avaudiosessioninterruptionreasonkey)、[AppWasSuspended理由](https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionreason/appwassuspended)、および実SDKの `AVAudioSessionTypes.h` とする。SDKでは旧キーをiOS 14.5、AppWasSuspended理由をiOS 16.0で非推奨とし、後者にはiOS 16以降にその通知が発生しない旨が記載されている。

更新時は公式archiveと各runtimeのハッシュ、OS別の中断フラグ変換とイベント配列、マイク権限無効時のiOSコンパイル、署名なしRunnerビルド、既存の音声回帰を確認する。実端末での着信・バックグラウンド・音声経路変更は別検証とする。適用後ハッシュと統合検証結果はリポジトリ共通のprovenance・互換性記録へ保存する。
