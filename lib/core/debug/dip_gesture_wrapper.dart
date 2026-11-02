import 'package:flutter/material.dart';

import '../config/feature_flags.dart';
import 'dip_controller.dart';

/// 3本指ダブルタップを検出してDIPメニューを表示するラッパー
///
/// アプリのルートウィジェットをこのウィジェットでラップすることで、
/// どの画面でも3本指ダブルタップでDIPメニューを呼び出せます。
class DipGestureWrapper extends StatefulWidget {
  const DipGestureWrapper({required this.child, super.key});

  final Widget child;

  @override
  State<DipGestureWrapper> createState() => _DipGestureWrapperState();
}

class _DipGestureWrapperState extends State<DipGestureWrapper> {
  DateTime? _lastTapTime;
  int _tapCount = 0;

  // ダブルタップの最大間隔（ミリ秒）
  static const _doubleTapTimeout = Duration(milliseconds: 500);

  // 必要な指の本数
  static const _requiredPointers = 3;

  void _handlePointerDown(PointerDownEvent event) {
    // DIPが無効の場合は何もしない
    if (!FeatureFlags.enableDip) return;

    final now = DateTime.now();

    // タイムアウトをチェック
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) > _doubleTapTimeout) {
      _tapCount = 0;
    }

    _lastTapTime = now;
  }

  void _handleMultiTap(int pointerCount) {
    // DIPが無効の場合は何もしない
    if (!FeatureFlags.enableDip) return;

    if (pointerCount >= _requiredPointers) {
      final now = DateTime.now();

      if (_lastTapTime != null &&
          now.difference(_lastTapTime!) <= _doubleTapTimeout) {
        _tapCount++;

        if (_tapCount >= 2) {
          _tapCount = 0;
          _showDip();
        }
      } else {
        _tapCount = 1;
      }

      _lastTapTime = now;
    }
  }

  void _showDip() {
    DipController.toggle(context);
  }

  @override
  Widget build(BuildContext context) {
    // DIPが無効の場合はラップせずそのまま返す
    if (!FeatureFlags.enableDip) {
      return widget.child;
    }

    return Listener(
      onPointerDown: _handlePointerDown,
      behavior: HitTestBehavior.translucent,
      child: _MultiTouchDetector(
        onMultiTap: _handleMultiTap,
        child: widget.child,
      ),
    );
  }
}

/// 複数の指でのタップを検出するウィジェット
class _MultiTouchDetector extends StatefulWidget {
  const _MultiTouchDetector({required this.child, required this.onMultiTap});

  final Widget child;
  final void Function(int pointerCount) onMultiTap;

  @override
  State<_MultiTouchDetector> createState() => _MultiTouchDetectorState();
}

class _MultiTouchDetectorState extends State<_MultiTouchDetector> {
  final Set<int> _activePointers = {};
  int _maxSimultaneousPointers = 0;
  DateTime? _firstPointerDownTime;

  // 全ての指が同時に触れていると判定する許容時間
  static const _simultaneousTapWindow = Duration(milliseconds: 300);

  void _onPointerDown(PointerDownEvent event) {
    final now = DateTime.now();

    // 最初のポインターの場合、時間をリセット
    if (_activePointers.isEmpty) {
      _firstPointerDownTime = now;
      _maxSimultaneousPointers = 0;
    }

    // 最初のポインターから許容時間内の場合のみカウント
    if (_firstPointerDownTime != null &&
        now.difference(_firstPointerDownTime!) <= _simultaneousTapWindow) {
      _activePointers.add(event.pointer);
      if (_activePointers.length > _maxSimultaneousPointers) {
        _maxSimultaneousPointers = _activePointers.length;
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);

    // 全ての指が離れた時にコールバックを呼び出す
    if (_activePointers.isEmpty && _maxSimultaneousPointers >= 3) {
      widget.onMultiTap(_maxSimultaneousPointers);
      _maxSimultaneousPointers = 0;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
