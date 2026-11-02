# CharmShelf UI効果音の生成

`generate_ui_sounds.py` は、NumPyによる波形合成から `tap`・`success`・`error` の3種類の効果音を作ります。外部の録音素材は読み込みません。音源と生成スクリプトの利用許諾は[公開素材の一覧](../../docs/ASSET_LICENSES.md)と[assets/LICENSE](../../assets/LICENSE)を参照してください。

## 再生成

リポジトリのルートで、アプリに同梱する音源とは別の出力先を指定します。

```sh
python3 -m venv build/ui-sounds-repro/.venv
build/ui-sounds-repro/.venv/bin/pip install -r tool/ui_sounds/requirements.txt
build/ui-sounds-repro/.venv/bin/python tool/ui_sounds/generate_ui_sounds.py \
  --output-dir build/ui-sounds-repro/output --no-zip
shasum -a 256 build/ui-sounds-repro/output/*.mp3 assets/sounds/tap.mp3 \
  assets/sounds/success.mp3 assets/sounds/error.mp3
```

依存版は `requirements.txt` に固定しています。MP3のエンコーダーはlameencを優先します。異なる環境や別エンコーダーで再生成するとバイト列が変わることがあるため、音とハッシュを確認してから同梱音源を変更してください。生成用のPython依存はアプリへ同梱しません。

このツールは3種類のUI効果音を扱います。他の公開サンプル音声・動画・画像の生成元は[公開素材の一覧](../../docs/ASSET_LICENSES.md)に記載しています。
