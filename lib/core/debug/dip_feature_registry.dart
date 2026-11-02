import 'dip_feature.dart';

/// DIP機能の登録・管理を行うレジストリ
///
/// シングルトンパターンで実装されており、アプリ全体で共有されます。
/// カスタム機能を追加する場合は [register] メソッドを使用します。
class DipFeatureRegistry {
  DipFeatureRegistry._();

  static final DipFeatureRegistry _instance = DipFeatureRegistry._();
  static DipFeatureRegistry get instance => _instance;

  final List<DipFeature> _features = [];
  bool _initialized = false;

  /// 登録済みの全機能を取得
  List<DipFeature> get features => List.unmodifiable(_features);

  /// DIPメニューに表示する機能を取得
  List<DipFeature> get dipFeatures =>
      _features.where((f) => f.showInDip).toList();

  /// 設定画面に表示する機能を取得
  List<DipFeature> get settingsFeatures =>
      _features.where((f) => f.showInSettings).toList();

  /// カテゴリ別にDIP機能を取得
  Map<DipFeatureCategory, List<DipFeature>> get featuresByCategory {
    final map = <DipFeatureCategory, List<DipFeature>>{};
    for (final feature in dipFeatures) {
      map.putIfAbsent(feature.category, () => []).add(feature);
    }
    return map;
  }

  /// 機能を登録
  void register(DipFeature feature) {
    // 重複チェック
    if (_features.any((f) => f.id == feature.id)) {
      throw ArgumentError('Feature with id "${feature.id}" already registered');
    }
    _features.add(feature);
  }

  /// 複数の機能をまとめて登録
  void registerAll(List<DipFeature> features) {
    for (final feature in features) {
      register(feature);
    }
  }

  /// 機能を登録解除
  void unregister(String id) {
    _features.removeWhere((f) => f.id == id);
  }

  /// 全機能をクリア
  void clear() {
    _features.clear();
    _initialized = false;
  }

  /// IDで機能を取得
  DipFeature? getById(String id) {
    try {
      return _features.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  /// デフォルト機能を初期化
  ///
  /// アプリ起動時に一度だけ呼び出してください。
  void initializeDefaults(List<DipFeature> defaultFeatures) {
    if (_initialized) return;
    registerAll(defaultFeatures);
    _initialized = true;
  }

  /// 初期化済みかどうか
  bool get isInitialized => _initialized;
}
