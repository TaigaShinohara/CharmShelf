import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feedback_providers.dart';
import 'haptics_service.dart';
import 'sound_service.dart';

/// アプリ全体の触覚フィードバックおよびサウンドフィードバックを一元管理するサービス
class FeedbackService {
  FeedbackService(this._ref);

  final Ref _ref;

  bool get _isHapticsEnabled => _ref.read(hapticsEnabledProvider);
  bool get _isSoundEnabled => _ref.read(soundEnabledProvider);

  /// 軽いタップ触覚（ボタン押下など）
  Future<void> lightImpact() async {
    if (_isHapticsEnabled) {
      await HapticsService.lightTap();
    }
  }

  /// 軽いタップ（エイリアス）
  Future<void> lightTap() async => lightImpact();

  /// 中程度のタップ触覚（モーダル表示、確定など）
  Future<void> mediumImpact() async {
    if (_isHapticsEnabled) {
      await HapticsService.mediumTap();
    }
  }

  /// 中程度のタップ（エイリアス）
  Future<void> mediumTap() async => mediumImpact();

  /// 強いタップ触覚（削除、警告など）
  Future<void> heavyImpact() async {
    if (_isHapticsEnabled) {
      await HapticsService.heavyTap();
    }
  }

  /// 強いタップ（エイリアス）
  Future<void> heavyTap() async => heavyImpact();

  /// セレクション（タブ・セグメント切り替え、Pickerスクロールなど）
  Future<void> selection() async {
    if (_isHapticsEnabled) {
      await HapticsService.selection();
    }
  }

  /// 通常のタップ操作（触覚 + タップ音）
  Future<void> tap() async {
    if (_isHapticsEnabled) {
      await HapticsService.lightTap();
    }
    if (_isSoundEnabled) {
      await _ref.read(soundServiceProvider).play(SoundType.tap);
    }
  }

  /// 成功時（触覚パターン + 成功音）
  Future<void> success() async {
    if (_isHapticsEnabled) {
      await HapticsService.success();
    }
    if (_isSoundEnabled) {
      await _ref.read(soundServiceProvider).play(SoundType.success);
    }
  }

  /// エラー時（触覚パターン + エラー音）
  Future<void> error() async {
    if (_isHapticsEnabled) {
      await HapticsService.error();
    }
    if (_isSoundEnabled) {
      await _ref.read(soundServiceProvider).play(SoundType.error);
    }
  }
}
