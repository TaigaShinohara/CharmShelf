# 撮影用の合成データ

`seed.dart` は、架空のMarkdown文書、表紙画像と撮影用Isarデータベースを作成する開発用ツールです。表紙には本リポジトリの手続き生成素材だけを使用します。アプリの通常のビルド・起動経路からは参照されません。

[開発環境の準備](../../docs/SETUP_GUIDE.md)を済ませた後、リポジトリのルートで実行します。

```sh
dart run tool/store_screenshots/seed.dart
```

出力先は `build/store-screenshot-fixture` に固定され、既存の出力先がある場合は上書きを拒否します。生成物の利用は、新しく作成した撮影専用の開発環境に限定してください。実機や普段使うシミュレーターのデータベースへコピーしないでください。

スクリーンショットの撮影と内容確認は別途行います。個人データ、実際のファイル名や保存場所、第三者の写真・書籍を掲載画像へ含めないでください。公開ソースには過去の撮影画像や端末データを含めていません。

素材の扱いは[公開素材の一覧とライセンス](../../docs/ASSET_LICENSES.md)を参照してください。

## 撮影計画と端末別の構成

最初の撮影計画に、カタログ一覧だけでなく、カタログを開いて中の資料を閲覧している実画面を含めます。基本の順序と原画像名は次のとおりです。

1. `01-library.png`: カタログ一覧
2. `02-catalog.png`: 「旅のしおり」を開き、中の資料が見える画面
3. `03-home.png`: お気に入りのカタログ
4. `04-charms.png`: チャームによる整理
5. `05-settings.png`: テーマ・言語設定

各端末の原画像を、提出用パックの `raw/iphone/`（1320×2868）、`raw/ipad/`（2064×2752）、`raw/android/`（1080×1920）に保存します。原画像は撮影後に目視し、起動待ち・エラー・表示途中の状態を除外してください。サイズは撮影機種が変われば公式仕様と合わせて見直します。

`build_projects.py` はこの5画面がすべてあることを確認してから、tiger_screen_shotで編集・再書き出しできるプロジェクトを生成します。Python標準ライブラリだけで実行できます。

```sh
python3 tool/store_screenshots/build_projects.py --pack /absolute/path/to/screenshot-pack
# iPadだけを再構成する場合
python3 tool/store_screenshots/build_projects.py --pack /absolute/path/to/screenshot-pack --devices ipad
```

iPadは独立した構成を使い、大きな2行見出しと、実画面の内容を読める拡大表示を最初から作ります。iPhone用の構成を単純拡大して、空の領域ばかりを見せないでください。拡大は原画像をそのまま埋め込んだSVGの表示範囲で行い、「実画面の一部を拡大表示」と記載します。原画像のハッシュと表示範囲は `projects/capture-provenance.json` に残します。UIの描き直しや別画面の部品の合成は行いません。撮影内容が変わった場合は `IPAD_CROPS` を実画面に合わせて調整し、意味のある文字が途中で切れていないか確認します。

書き出しには利用者が用意したtiger_screen_shotのCLIとエディターを使います。CLIやブラウザーの一時ファイルは、十分な空き容量のある場所に置いてください。

```sh
OSG_EDITOR_DIR=/path/to/tiger_screen_shot/out \
  node /path/to/tiger_screen_shot/cli/dist/cli.js render \
  --config /absolute/path/to/screenshot-pack/projects/ipad.config.json --json
```

同じように `iphone.config.json`、`iphone-medium.config.json`、`android.config.json` も書き出します。生成されるのは日本語5画面×4形式の20枚です。寸法・透過・ファイル容量を検証したうえで、全画像をストアの縮小プレビュー程度の大きさでも目視します。見出しと主要な内容が読めること、不要な余白が支配していないこと、カタログの中身を開いた画面があることを完成条件にします。実画面の文字が小さいままなら、完了扱いにせず構成を調整して再書き出しします。
