import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// ログレベル
enum DipLogLevel {
  debug(Colors.grey, Icons.bug_report),
  info(Colors.blue, Icons.info),
  warning(Colors.orange, Icons.warning),
  error(Colors.red, Icons.error),
  success(Colors.green, Icons.check_circle);

  const DipLogLevel(this.color, this.icon);
  final Color color;
  final IconData icon;
}

/// ログエントリ
class DipLogEntry {
  DipLogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
    this.tag,
  });

  final String message;
  final DipLogLevel level;
  final DateTime timestamp;
  final String? tag;

  @override
  String toString() {
    final tagStr = tag != null ? '[$tag] ' : '';
    return '${timestamp.toIso8601String()} [${level.name.toUpperCase()}] $tagStr$message';
  }
}

/// DipActionLogの状態
class DipActionLogState {
  DipActionLogState({
    this.enabled = false,
    List<DipLogEntry>? logs,
    this.maxLogs = 500,
  }) : logs = logs ?? [];

  final bool enabled;
  final List<DipLogEntry> logs;
  final int maxLogs;

  DipActionLogState copyWith({
    bool? enabled,
    List<DipLogEntry>? logs,
    int? maxLogs,
  }) {
    return DipActionLogState(
      enabled: enabled ?? this.enabled,
      logs: logs ?? this.logs,
      maxLogs: maxLogs ?? this.maxLogs,
    );
  }
}

/// DipActionLogの状態管理
class DipActionLogNotifier extends StateNotifier<DipActionLogState> {
  DipActionLogNotifier() : super(DipActionLogState());

  /// ログ表示を有効/無効にする
  void setEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
  }

  /// ログを追加
  void addLog(DipLogEntry entry) {
    final newLogs = [...state.logs, entry];
    // 最大件数を超えたら古いログを削除
    if (newLogs.length > state.maxLogs) {
      newLogs.removeRange(0, newLogs.length - state.maxLogs);
    }
    state = state.copyWith(logs: newLogs);
  }

  /// ログをクリア
  void clearLogs() {
    state = state.copyWith(logs: []);
  }
}

/// DipActionLogのProvider
final dipActionLogProvider =
    StateNotifierProvider<DipActionLogNotifier, DipActionLogState>(
      (ref) => DipActionLogNotifier(),
    );

/// アプリ内動作ログをSnackBarで表示するシステム
///
/// 開発中のデバッグに便利なログ表示機能です。
/// DIPメニューからON/OFFを切り替えることができます。
class DipActionLog {
  DipActionLog._();

  static final _logs = Queue<DipLogEntry>();
  static const _maxLogs = 500;
  static bool _enabled = false;
  static GlobalKey<ScaffoldMessengerState>? _messengerKey;
  static WidgetRef? _ref;

  /// 初期化
  static void init({
    GlobalKey<ScaffoldMessengerState>? messengerKey,
    WidgetRef? ref,
  }) {
    _messengerKey = messengerKey;
    _ref = ref;
  }

  /// 有効/無効を設定
  static void setEnabled(bool enabled) {
    _enabled = enabled;
    _ref?.read(dipActionLogProvider.notifier).setEnabled(enabled);
  }

  /// 現在の有効状態を取得
  static bool get isEnabled => _enabled;

  /// ログ一覧を取得
  static List<DipLogEntry> get logs => _logs.toList();

  /// ログをクリア
  static void clearLogs() {
    _logs.clear();
    _ref?.read(dipActionLogProvider.notifier).clearLogs();
  }

  /// ログを記録（SnackBar表示は有効時のみ）
  static void log(
    String message, {
    DipLogLevel level = DipLogLevel.info,
    String? tag,
    bool showSnackBar = true,
  }) {
    final entry = DipLogEntry(
      message: message,
      level: level,
      timestamp: DateTime.now(),
      tag: tag,
    );

    // ログを保存
    _logs.addLast(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }
    _ref?.read(dipActionLogProvider.notifier).addLog(entry);

    // SnackBar表示（有効時のみ）
    if (_enabled && showSnackBar) {
      _showSnackBar(entry);
    }
  }

  /// デバッグログ
  static void debug(String message, {String? tag}) {
    log(message, level: DipLogLevel.debug, tag: tag);
  }

  /// 情報ログ
  static void info(String message, {String? tag}) {
    log(message, level: DipLogLevel.info, tag: tag);
  }

  /// 警告ログ
  static void warning(String message, {String? tag}) {
    log(message, level: DipLogLevel.warning, tag: tag);
  }

  /// エラーログ
  static void error(String message, {String? tag}) {
    log(message, level: DipLogLevel.error, tag: tag);
  }

  /// 成功ログ
  static void success(String message, {String? tag}) {
    log(message, level: DipLogLevel.success, tag: tag);
  }

  static void _showSnackBar(DipLogEntry entry) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(entry.level.icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.tag != null
                  ? '[${entry.tag}] ${entry.message}'
                  : entry.message,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: entry.level.color.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
    );
    if (appSnackBarOverlayKey.currentState != null) {
      AppSnackBarMessenger.showGlobal(snackBar);
    } else {
      _messengerKey?.currentState?.showSnackBar(snackBar);
    }
  }
}
