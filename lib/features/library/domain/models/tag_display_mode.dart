/// タグ一覧およびタグ選択画面での表示モード
enum TagDisplayMode {
  /// Facet単位（フラットグループ）
  facet,

  /// 親子階層（グローバルツリー）
  hierarchy,

  /// ハイブリッド（Facet内ツリー）
  hybrid,
}
