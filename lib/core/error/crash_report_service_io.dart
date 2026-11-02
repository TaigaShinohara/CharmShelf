import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logger/app_logger.dart';
import '../logger/log_tag.dart';
import '../services/private_storage_service.dart';
import 'crash_report_model.dart';
import 'crash_report_privacy.dart';

/// Stores only allowlisted diagnostics, in every build mode. Old reports are
/// anonymized before they can be returned, displayed, copied or exported.
class CrashReportService {
  CrashReportService._()
    : _beforeReplace = null,
      _privateDirectory = PrivateStorageService.getDirectory;

  @visibleForTesting
  CrashReportService.forTesting({
    this._beforeReplace,
    Future<Directory> Function()? privateDirectory,
  }) : _privateDirectory =
           privateDirectory ?? PrivateStorageService.getDirectory;

  static final CrashReportService _instance = CrashReportService._();
  static CrashReportService get instance => _instance;
  static const int _maxReports = 10;
  static const String _crashLogFileName = 'crash_reports.json';
  static int _stagingSequence = 0;

  final Future<void> Function(File temporary, File destination)? _beforeReplace;
  final Future<Directory> Function() _privateDirectory;
  AppInfo? _cachedAppInfo;

  /// Kept for caller compatibility; route strings are never recorded.
  String? currentRoute;

  Future<void> _writeQueue = Future.value();

  /// Serializes reads, migrations, writes and explicit deletes. A failed
  /// operation is reported to its caller without poisoning later retries.
  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> initialize() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedAppInfo = AppInfo(
        appName: info.appName,
        packageName: info.packageName,
        version: info.version,
        buildNumber: info.buildNumber,
      );
    } catch (_) {
      AppLogger.w(LogTag.app, 'クラッシュレポートのアプリ情報を取得できませんでした');
    }
    await _serialized(() async {
      final target = await _getCrashLogFile();
      // Interrupted writes from older versions can also contain private data.
      await _anonymizeAbandonedTemporary(File('${target.path}.tmp'));
      await _readReports(target);
      for (final legacy in await _legacyFiles()) {
        await _anonymizeAbandonedTemporary(File('${legacy.path}.tmp'));
        await _migrateLegacyReports(legacy, target, await _readReports(target));
      }
    });
  }

  Future<CrashReport?> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final now = DateTime.now();
      // Do not call error.toString() or stackTrace.toString(): their content
      // may include arbitrary paths, credentials or other personal data.
      final report = CrashReport(
        id: '${now.millisecondsSinceEpoch}_${now.microsecond}',
        timestamp: now,
        errorType: CrashReportPrivacy.errorType(error),
        errorMessage: CrashReportPrivacy.omittedMessage,
        appInfo: _cachedAppInfo,
        additionalData: additionalData,
      ).sanitized();
      await _serialized(() async {
        final file = await _getCrashLogFile();
        final reports = await _readReports(file);
        reports.insert(0, report);
        await _writeReports(file, reports.take(_maxReports).toList());
      });
      return report;
    } catch (_) {
      AppLogger.e(LogTag.app, 'クラッシュレポートを保存できませんでした');
      return null;
    }
  }

  List<CrashReport> _decodeReports(Object? decoded) {
    if (decoded is! List) {
      throw const FormatException('Invalid crash report list');
    }
    return decoded.map((value) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid crash report entry');
      }
      return CrashReport.fromJson(value);
    }).toList();
  }

  Object? _decodeJson(String content) {
    try {
      return content.trim().isEmpty ? [] : jsonDecode(content);
    } on FormatException {
      // jsonDecode's exception can retain an excerpt of the old private data.
      throw const FormatException('Invalid crash report JSON');
    }
  }

  Future<List<CrashReport>> _readReports(File file) async {
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    final decoded = _decodeJson(content);
    final reports = _decodeReports(decoded);
    final safeJson = reports.map((report) => report.toJson()).toList();
    if (jsonEncode(decoded) != jsonEncode(safeJson)) {
      await _atomicWriteJson(file, safeJson);
    }
    return reports;
  }

  Future<void> _anonymizeAbandonedTemporary(File file) async {
    if (!await file.exists()) return;
    final content = await file.readAsString();
    final decoded = _decodeJson(content);
    final Object safe;
    if (decoded is Map<String, dynamic> && decoded['migrationVersion'] == 1) {
      safe = {
        'migrationVersion': 1,
        'reports': _decodeReports(
          decoded['reports'],
        ).map((report) => report.toJson()).toList(),
      };
    } else {
      safe = _decodeReports(decoded).map((report) => report.toJson()).toList();
    }
    if (jsonEncode(decoded) != jsonEncode(safe)) {
      await _atomicWriteJson(file, safe);
    }
  }

  /// Keep legacy diagnostics in place, safely anonymized, rather than deleting
  /// the original on a failed migration. The marker prevents later explicit
  /// report deletion from being undone by importing the same legacy file again.
  Future<void> _migrateLegacyReports(
    File legacy,
    File target,
    List<CrashReport> current,
  ) async {
    if (!await legacy.exists()) return;
    final content = await legacy.readAsString();
    final decoded = _decodeJson(content);
    final bool migrated;
    final List<CrashReport> legacyReports;
    if (decoded is Map<String, dynamic> && decoded['migrationVersion'] == 1) {
      migrated = true;
      legacyReports = _decodeReports(decoded['reports']);
    } else {
      migrated = false;
      legacyReports = _decodeReports(decoded);
    }
    if (!migrated) {
      final ids = current.map((report) => report.id).toSet();
      final merged = [
        ...current,
        ...legacyReports.where((report) => ids.add(report.id)),
      ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      // Commit the destination before marking the source as migrated. Any
      // failure preserves the original source and is retryable without loss.
      await _writeReports(target, merged.take(_maxReports).toList());
    }
    final safeLegacy = {
      'migrationVersion': 1,
      'reports': legacyReports.map((report) => report.toJson()).toList(),
    };
    if (jsonEncode(decoded) != jsonEncode(safeLegacy)) {
      await _atomicWriteJson(legacy, safeLegacy);
    }
  }

  Future<void> _writeReports(File file, List<CrashReport> reports) =>
      _atomicWriteJson(file, reports.map((report) => report.toJson()).toList());

  /// Verify the actual staged bytes before atomic publication. No malformed
  /// source is cleared, and no destination is replaced before validation.
  Future<void> _atomicWriteJson(File file, Object data) async {
    final content = const JsonEncoder.withIndent('  ').convert(data);
    final temporary = File(
      '${file.path}.privacy-${DateTime.now().microsecondsSinceEpoch}-${_stagingSequence++}.tmp',
    );
    await temporary.writeAsString(content, flush: true);
    await _beforeReplace?.call(temporary, file);
    final staged = await temporary.readAsString();
    if (staged != content ||
        jsonEncode(_decodeJson(staged)) != jsonEncode(data)) {
      throw const FormatException('Crash report staging verification failed');
    }
    // On failure, staging remains safe data for retry. The original report is
    // never removed or overwritten before this verified atomic replacement.
    await temporary.rename(file.path);
  }

  Future<File> _getCrashLogFile() async {
    final directory = await getApplicationSupportDirectory();
    final logDir = Directory(p.join(directory.path, 'logs'));
    if (!await logDir.exists()) await logDir.create(recursive: true);
    await PrivateStorageService.enforceBackupExclusion(logDir);
    return File(p.join(logDir.path, _crashLogFileName));
  }

  Future<List<CrashReport>> getAllReports() => _serialized(() async {
    final file = await _getCrashLogFile();
    return _readReports(file);
  });

  Future<CrashReport?> getReport(String id) async {
    final reports = await getAllReports();
    for (final report in reports) {
      if (report.id == id) return report;
    }
    return null;
  }

  Future<List<File>> _legacyFiles() async {
    final documents = await getApplicationDocumentsDirectory();
    final private = await _privateDirectory();
    return {
      p.join(documents.path, _crashLogFileName),
      p.join(private.path, _crashLogFileName),
    }.map(File.new).toList();
  }

  Future<List<File>> _knownReportFiles() async {
    final primary = [await _getCrashLogFile(), ...await _legacyFiles()];
    final files = <String, File>{};
    for (final file in primary) {
      if (await file.exists()) files[file.path] = file;
      if (!await file.parent.exists()) continue;
      await for (final item in file.parent.list(followLinks: false)) {
        final name = p.basename(item.path);
        if (item is File &&
            name.startsWith('$_crashLogFileName.') &&
            name.endsWith('.tmp')) {
          files[item.path] = item;
        }
      }
    }
    return files.values.toList();
  }

  /// Explicit user deletion also removes retained legacy and interrupted-write
  /// copies. A failure is surfaced, and retry visits all remaining copies.
  Future<void> clearAllReports() => _serialized(() async {
    for (final file in await _knownReportFiles()) {
      await file.delete();
    }
  });

  Future<void> deleteReport(String id) => _serialized(() async {
    final updates = <File, Object>{};
    // Validate every original before changing any copy. Unique staging names
    // ensure another retained staging file is never clobbered during this work.
    for (final file in await _knownReportFiles()) {
      final decoded = _decodeJson(await file.readAsString());
      if (decoded is Map<String, dynamic> && decoded['migrationVersion'] == 1) {
        updates[file] = {
          'migrationVersion': 1,
          'reports': _decodeReports(decoded['reports'])
              .where((report) => report.id != id)
              .map((report) => report.toJson())
              .toList(),
        };
      } else {
        updates[file] = _decodeReports(decoded)
            .where((report) => report.id != id)
            .map((report) => report.toJson())
            .toList();
      }
    }
    for (final update in updates.entries) {
      await _atomicWriteJson(update.key, update.value);
    }
  });

  Future<void> copyReportToClipboard(CrashReport report) async {
    await Clipboard.setData(ClipboardData(text: report.toDetailString()));
  }

  Future<String> exportAllReports() async {
    final reports = await getAllReports();
    if (reports.isEmpty) return 'No crash reports found.';
    final buffer = StringBuffer()
      ..writeln('CRASH REPORTS EXPORT')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('Total Reports: ${reports.length}')
      ..writeln();
    for (final report in reports) {
      buffer
        ..writeln(report.toDetailString())
        ..writeln();
    }
    return buffer.toString();
  }

  Future<int> getReportCount() async => (await getAllReports()).length;
}
