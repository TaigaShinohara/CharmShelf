/// ログレベル
///
/// 優先度の低い順に: verbose < debug < info < warning < error
/// developerLevelはdart:developerのlog関数で使用するレベル値
enum LogLevel {
  verbose(0, '🔍', 'V', 300),
  debug(1, '🐛', 'D', 500),
  info(2, 'ℹ️ ', 'I', 800),
  warning(3, '⚠️ ', 'W', 900),
  error(4, '❌', 'E', 1000);

  const LogLevel(this.priority, this.icon, this.shortName, this.developerLevel);

  final int priority;
  final String icon;
  final String shortName;

  /// dart:developerのlog関数で使用するレベル値
  /// 0-500: Fine/Verbose, 500-800: Debug, 800-900: Info, 900-1000: Warning, 1000+: Error
  final int developerLevel;
}
