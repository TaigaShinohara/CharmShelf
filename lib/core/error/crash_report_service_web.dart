import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../logger/app_logger.dart';
import '../logger/log_tag.dart';
import 'crash_report_model.dart';
import 'crash_report_privacy.dart';

/// クラッシュレポートを収集・保存するサービス（Web用）
///
/// Webではローカルファイル保存ができない/前提が異なるため、
/// **メモリ内のみ**に保持します（ページリロードで消えます）。
class CrashReportService {
  CrashReportService._();

  @visibleForTesting
  CrashReportService.forTesting();

  static final CrashReportService _instance = CrashReportService._();
  static CrashReportService get instance => _instance;

  static const int _maxReports = 10;

  AppInfo? _cachedAppInfo;
  String? currentRoute;

  final List<CrashReport> _reports = <CrashReport>[];

  Future<void> initialize() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _cachedAppInfo = AppInfo(
        appName: packageInfo.appName,
        packageName: packageInfo.packageName,
        version: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      );
      AppLogger.i(LogTag.app, 'クラッシュレポートサービス(Web)を初期化完了');
    } catch (_) {
      AppLogger.w(LogTag.app, 'クラッシュレポートサービス(Web)の初期化に失敗');
    }
  }

  Future<CrashReport?> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final report = await _createReport(
        error,
        stackTrace,
        context: context,
        additionalData: additionalData,
      );

      _reports.insert(0, report);
      while (_reports.length > _maxReports) {
        _reports.removeLast();
      }

      AppLogger.i(LogTag.app, 'クラッシュレポート(Web)を記録: ${report.id}');
      return report;
    } catch (_) {
      AppLogger.e(LogTag.app, 'クラッシュレポート(Web)の記録に失敗');
      return null;
    }
  }

  Future<CrashReport> _createReport(
    Object error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? additionalData,
  }) async {
    final id = _generateId();
    final timestamp = DateTime.now();

    return CrashReport(
      id: id,
      timestamp: timestamp,
      errorType: CrashReportPrivacy.errorType(error),
      errorMessage: CrashReportPrivacy.omittedMessage,
      appInfo: _cachedAppInfo,
      additionalData: additionalData,
    ).sanitized();
  }

  String _generateId() {
    final now = DateTime.now();
    return '${now.millisecondsSinceEpoch}_${now.microsecond}';
  }

  Future<List<CrashReport>> getAllReports() async =>
      List.unmodifiable(_reports.map((report) => report.sanitized()));

  Future<CrashReport?> getReport(String id) async {
    try {
      return _reports.firstWhere((r) => r.id == id).sanitized();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAllReports() async {
    _reports.clear();
    AppLogger.i(LogTag.app, '全てのクラッシュレポート(Web)を削除');
  }

  Future<void> deleteReport(String id) async {
    _reports.removeWhere((r) => r.id == id);
    AppLogger.i(LogTag.app, 'クラッシュレポート(Web)を削除');
  }

  Future<void> copyReportToClipboard(CrashReport report) async {
    await Clipboard.setData(ClipboardData(text: report.toDetailString()));
  }

  Future<String> exportAllReports() async {
    final reports = await getAllReports();
    if (reports.isEmpty) return 'No crash reports found.';

    final buffer = StringBuffer();
    buffer.writeln('CRASH REPORTS EXPORT');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total Reports: ${reports.length}');
    buffer.writeln('');

    for (final report in reports) {
      buffer.writeln(report.toDetailString());
      buffer.writeln('');
    }

    return buffer.toString();
  }

  Future<int> getReportCount() async => _reports.length;
}
