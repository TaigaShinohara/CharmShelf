import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'dip_overlay.dart';

/// DIPの表示状態を管理するProvider
final dipVisibleProvider = StateProvider<bool>((ref) => false);

/// DIPのコントローラー
///
/// DIPメニューの表示/非表示を制御します。
class DipController {
  DipController._();

  static OverlayEntry? _overlayEntry;
  static final GlobalKey<DipOverlayState> _overlayKey =
      GlobalKey<DipOverlayState>();

  /// 最後に使用したOverlayStateへの参照
  /// パネルから戻った際の再表示に使用
  static OverlayState? _lastOverlay;

  /// DIPメニューを表示
  static void show(BuildContext context) {
    if (_overlayEntry != null) return;

    // Overlayを取得（見つからない場合はnullを返す）
    final overlay = _findOverlay(context);
    if (overlay == null) {
      debugPrint('[DIP] Warning: No Overlay found, cannot show DIP');
      return;
    }

    _lastOverlay = overlay;

    _overlayEntry = OverlayEntry(
      builder: (context) => DipOverlay(key: _overlayKey, onClose: hide),
    );

    overlay.insert(_overlayEntry!);
  }

  /// 最後に使用したOverlayを使ってDIPを再表示
  ///
  /// パネルから戻った際など、コンテキストが不安定な場合に使用
  static void showWithLastOverlay() {
    if (_overlayEntry != null) return;
    if (_lastOverlay == null || !_lastOverlay!.mounted) {
      debugPrint('[DIP] Warning: No valid last overlay, cannot show DIP');
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => DipOverlay(key: _overlayKey, onClose: hide),
    );

    _lastOverlay!.insert(_overlayEntry!);
  }

  /// コンテキストからOverlayを安全に取得
  static OverlayState? _findOverlay(BuildContext context) {
    try {
      // まずrootNavigatorのOverlayを試す
      final rootNav = Navigator.maybeOf(context, rootNavigator: true);
      if (rootNav != null) {
        final overlay = rootNav.overlay;
        if (overlay != null && overlay.mounted) {
          return overlay;
        }
      }

      // 通常のOverlay.of()を試す
      return Overlay.maybeOf(context);
    } catch (e) {
      debugPrint('[DIP] Error finding overlay: $e');
      return null;
    }
  }

  /// DIPメニューを非表示
  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// DIPメニューの表示/非表示を切り替え
  static void toggle(BuildContext context) {
    if (_overlayEntry != null) {
      hide();
    } else {
      show(context);
    }
  }

  /// DIPメニューが表示中かどうか
  static bool get isVisible => _overlayEntry != null;
}
