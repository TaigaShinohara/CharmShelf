import 'package:flutter/services.dart';

import '../config/feature_flags.dart';
import '../logger/app_logger.dart';
import '../logger/log_tag.dart';

/// 端末の触覚フィードバック（バイブレーション）を制御するユーティリティクラス
class HapticsService {
  HapticsService._();

  static bool _userEnabled = true;

  /// ユーザー設定による有効/無効の同期状態を更新します
  static void updateUserEnabled(bool enabled) {
    _userEnabled = enabled;
  }

  /// 現在触覚フィードバックが有効化されているかどうか
  static bool get isEnabled => FeatureFlags.enableHaptics && _userEnabled;

  static Future<void> _safelyExecute(Future<void> Function() action) async {
    if (!isEnabled) return;
    try {
      await action();
    } catch (e, st) {
      AppLogger.w(LogTag.ui, '触覚フィードバックの実行に失敗しました', e, st);
    }
  }

  /// 軽いタップ感（ボタンタップ、選択など）
  static Future<void> lightTap() async =>
      _safelyExecute(HapticFeedback.lightImpact);

  /// 中程度のタップ感（モーダル表示、確定など）
  static Future<void> mediumTap() async =>
      _safelyExecute(HapticFeedback.mediumImpact);

  /// 強いタップ感（削除、警告など）
  static Future<void> heavyTap() async =>
      _safelyExecute(HapticFeedback.heavyImpact);

  /// 軽い衝撃フィードバック
  static Future<void> lightImpact() async => lightTap();

  /// 中程度の衝撃フィードバック
  static Future<void> mediumImpact() async => mediumTap();

  /// 強い衝撃フィードバック
  static Future<void> heavyImpact() async => heavyTap();

  /// セレクション（Pickerやタブ等の切り替え）
  static Future<void> selection() async =>
      _safelyExecute(HapticFeedback.selectionClick);

  /// セレクション（エイリアス）
  static Future<void> selectionClick() async => selection();

  /// 成功時のフィードバックパターン
  static Future<void> success() async {
    await _safelyExecute(() async {
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.lightImpact();
    });
  }

  /// エラー時のフィードバックパターン
  static Future<void> error() async {
    await _safelyExecute(() async {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
    });
  }
}
