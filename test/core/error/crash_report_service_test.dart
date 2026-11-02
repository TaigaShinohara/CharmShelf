import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/error/crash_report_model.dart';
import 'package:private_shelf/core/error/crash_report_privacy.dart';
import 'package:private_shelf/core/error/crash_report_service.dart';
import 'package:private_shelf/core/error/crash_report_service_web.dart' as web;
import 'package:private_shelf/core/error/error_handler.dart';

const _private = 'SYNTHETIC_PRIVATE_SENTINEL';
const _email = 'synthetic-sentinel@example.invalid';
const _path = '/private/synthetic-sentinel/secret-file';

class _PrivateError implements Exception {
  @override
  String toString() => throw StateError('Error contents must not be evaluated');
}

Map<String, dynamic> _legacyReport({int number = 0}) => {
  'id': 'legacy-$_private-$number',
  'timestamp': DateTime.utc(2026, 1, 1, 0, 0, number).toIso8601String(),
  'errorType': 'FileSystemException',
  'errorMessage': '$_private $_email $_path',
  'stackTrace': '$_private $_path',
  'currentRoute': '/viewer/$_email',
  'deviceInfo': {'platform': _private, 'model': _email},
  'appInfo': {
    'appName': _private,
    'packageName': _email,
    'version': '1.2.3',
    'buildNumber': '42',
  },
  'memoryInfo': {'usedHeapSize': _private},
  'additionalData': {
    'errorSource': 'platform',
    'context': {
      'secret': [_private, _email, _path],
    },
    _private: _email,
  },
};

void _expectSafe(String value) {
  expect(value, isNot(contains(_private)));
  expect(value, isNot(contains(_email)));
  expect(value, isNot(contains(_path)));
}

Future<List<File>> _stagingFor(File file) async => file.parent
    .list()
    .where(
      (entry) =>
          entry is File && entry.path.startsWith('${file.path}.privacy-'),
    )
    .cast<File>()
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docsDir;
  late Directory supportDir;
  late File current;
  late File legacy;
  String? clipboardText;

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('crash_docs_test_');
    supportDir = await Directory.systemTemp.createTemp('crash_support_test_');
    current = File(p.join(supportDir.path, 'logs', 'crash_reports.json'));
    legacy = File(p.join(docsDir.path, 'crash_reports.json'));
    clipboardText = null;
    PackageInfo.setMockInitialValues(
      appName: _private,
      packageName: _email,
      version: '1.2.3',
      buildNumber: '42',
      buildSignature: '',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => switch (call.method) {
        'getApplicationDocumentsDirectory' => docsDir.path,
        'getApplicationSupportDirectory' => supportDir.path,
        _ => null,
      },
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
  });

  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    await docsDir.delete(recursive: true);
    await supportDir.delete(recursive: true);
  });

  test(
    'persistent JSON, return value, clipboard and export omit arbitrary data',
    () async {
      final service = CrashReportService.forTesting();
      await service.initialize();
      service.currentRoute = '/$_private/$_email';
      final report = await service.recordError(
        _PrivateError(),
        StackTrace.fromString('$_private $_path'),
        context: _email,
        additionalData: {
          'errorSource': 'platform',
          'context': {
            'secret': [_private, _email, _path],
          },
        },
      );
      expect(report, isNotNull);
      expect(report!.errorType, 'Error');
      expect(report.errorMessage, CrashReportPrivacy.omittedMessage);
      expect(report.additionalData, {'errorSource': 'platform'});
      expect(report.stackTrace, isNull);
      expect(report.currentRoute, isNull);
      final persisted = await current.readAsString();
      _expectSafe(persisted);
      expect(jsonDecode(persisted), hasLength(1));
      expect(await legacy.exists(), isFalse);
      _expectSafe(jsonEncode(report.toJson()));
      _expectSafe(report.summary);
      _expectSafe(await service.exportAllReports());
      await service.copyReportToClipboard(report);
      _expectSafe(clipboardText!);
      expect(report.appInfo!.version, '1.2.3');
      expect(report.appInfo!.buildNumber, '42');
    },
  );

  test(
    'model boundaries use the same allowlist for untrusted legacy metadata',
    () {
      final json = _legacyReport()
        ..['errorType'] = _private
        ..['appInfo'] = {
          'appName': _private,
          'packageName': _email,
          'version': '1.0-$_private',
          'buildNumber': _email,
        }
        ..['additionalData'] = {
          'errorSource': _private,
          'nested': {'secret': _email},
        };
      final report = CrashReport.fromJson(json);
      expect(report.errorType, 'Error');
      expect(report.appInfo, isNull);
      expect(report.additionalData, isNull);
      _expectSafe(jsonEncode(report.toJson()));
      _expectSafe(report.summary);
      _expectSafe(report.toDetailString());
      expect(report.toJson(), CrashReport.fromJson(report.toJson()).toJson());
    },
  );

  test(
    'copy and display sanitize even a directly constructed report',
    () async {
      final report = CrashReport(
        id: _email,
        timestamp: DateTime.utc(2026),
        errorType: _private,
        errorMessage: _private,
        stackTrace: _path,
        currentRoute: _email,
        additionalData: {'context': _private},
      );
      _expectSafe(report.summary);
      _expectSafe(report.toDetailString());
      await CrashReportService.forTesting().copyReportToClipboard(report);
      _expectSafe(clipboardText!);
      await web.CrashReportService.forTesting().copyReportToClipboard(report);
      _expectSafe(clipboardText!);
    },
  );

  test(
    'reading existing logs atomically anonymizes them before return',
    () async {
      await current.parent.create(recursive: true);
      await current.writeAsString(jsonEncode([_legacyReport()]));
      final service = CrashReportService.forTesting();
      final reports = await service.getAllReports();
      expect(reports.single.errorType, 'FileSystemException');
      expect(reports.single.additionalData, {'errorSource': 'platform'});
      _expectSafe(await current.readAsString());
      _expectSafe(await service.exportAllReports());
    },
  );

  test(
    'legacy migration retains anonymized source and does not reimport deletions',
    () async {
      await legacy.writeAsString(jsonEncode([_legacyReport()]));
      final service = CrashReportService.forTesting();
      await service.initialize();
      expect(await legacy.exists(), isTrue);
      final source = await legacy.readAsString();
      _expectSafe(source);
      expect((jsonDecode(source) as Map)['migrationVersion'], 1);
      final reports = await service.getAllReports();
      expect(reports, hasLength(1));
      _expectSafe(await current.readAsString());
      await service.deleteReport(reports.single.id);
      await service.initialize();
      expect(await service.getAllReports(), isEmpty);
      _expectSafe(await legacy.readAsString());
    },
  );

  test(
    'failed destination migration preserves legacy bytes and succeeds on retry',
    () async {
      final original = jsonEncode([_legacyReport()]);
      await legacy.writeAsString(original);
      var fail = true;
      final service = CrashReportService.forTesting(
        beforeReplace: (_, destination) async {
          if (destination.path == current.path && fail) {
            throw const FileSystemException('Synthetic publication failure');
          }
        },
      );
      await expectLater(
        service.initialize(),
        throwsA(isA<FileSystemException>()),
      );
      expect(await legacy.readAsString(), original);
      expect(await current.exists(), isFalse);
      _expectSafe(await (await _stagingFor(current)).single.readAsString());
      fail = false;
      await service.initialize();
      expect(await service.getAllReports(), hasLength(1));
      _expectSafe(await legacy.readAsString());
      _expectSafe(await current.readAsString());
    },
  );

  test(
    'failed source anonymization retries without duplicating migrated reports',
    () async {
      final original = jsonEncode([_legacyReport()]);
      await legacy.writeAsString(original);
      var fail = true;
      final service = CrashReportService.forTesting(
        beforeReplace: (_, destination) async {
          if (destination.path == legacy.path && fail) {
            throw const FileSystemException(
              'Synthetic source publication failure',
            );
          }
        },
      );
      await expectLater(
        service.initialize(),
        throwsA(isA<FileSystemException>()),
      );
      expect(await legacy.readAsString(), original);
      _expectSafe(await current.readAsString());
      fail = false;
      await service.initialize();
      await service.initialize();
      expect(await service.getAllReports(), hasLength(1));
      _expectSafe(await legacy.readAsString());
    },
  );

  test(
    'corrupt existing logs are preserved and never silently overwritten',
    () async {
      await current.parent.create(recursive: true);
      const original = '[{"id":"$_private", "timestamp":';
      await current.writeAsString(original);
      final service = CrashReportService.forTesting();
      await expectLater(service.initialize(), throwsFormatException);
      await expectLater(service.getAllReports(), throwsFormatException);
      try {
        await service.getAllReports();
        fail('A corrupt report must be reported to the caller');
      } on FormatException catch (error) {
        _expectSafe(error.toString());
      }
      expect(await service.recordError(StateError(_private), null), isNull);
      expect(await current.readAsString(), original);
    },
  );

  test('corrupt legacy logs are retained after failed migration', () async {
    const original = '[{"timestamp":';
    await legacy.writeAsString(original);
    await expectLater(
      CrashReportService.forTesting().initialize(),
      throwsFormatException,
    );
    expect(await legacy.readAsString(), original);
    expect(await current.exists(), isFalse);
  });

  test(
    'staged bytes are re-read and verified before replacing the original',
    () async {
      await current.parent.create(recursive: true);
      final original = jsonEncode([_legacyReport()]);
      await current.writeAsString(original);
      var corrupt = true;
      final service = CrashReportService.forTesting(
        beforeReplace: (temporary, _) async {
          if (corrupt) await temporary.writeAsString('[]');
        },
      );
      await expectLater(service.getAllReports(), throwsFormatException);
      expect(await current.readAsString(), original);
      corrupt = false;
      expect(await service.getAllReports(), hasLength(1));
      _expectSafe(await current.readAsString());
    },
  );

  test(
    'abandoned old staging logs are anonymized without deleting reports',
    () async {
      await current.parent.create(recursive: true);
      final pending = File('${current.path}.tmp');
      await pending.writeAsString(jsonEncode([_legacyReport()]));
      await CrashReportService.forTesting().initialize();
      expect(await pending.exists(), isTrue);
      _expectSafe(await pending.readAsString());
      expect(jsonDecode(await pending.readAsString()), hasLength(1));
    },
  );

  test(
    'parallel saves retain the latest ten reports without lost updates',
    () async {
      final service = CrashReportService.forTesting();
      await service.initialize();
      final saved = await Future.wait(
        List.generate(
          18,
          (_) => service.recordError(StateError(_private), null),
        ),
      );
      expect(saved.every((report) => report != null), isTrue);
      final reports = await service.getAllReports();
      expect(reports, hasLength(10));
      expect(reports.map((report) => report.id).toSet(), hasLength(10));
      expect(
        reports.map((report) => report.id).toList(),
        saved.skip(8).map((report) => report!.id).toList().reversed.toList(),
      );
      _expectSafe(await current.readAsString());
    },
  );

  test(
    'a failed save is visible and does not poison subsequent saves',
    () async {
      var fail = true;
      final service = CrashReportService.forTesting(
        beforeReplace: (_, _) async {
          if (fail) throw const FileSystemException('Synthetic write failure');
        },
      );
      await service.initialize();
      expect(await service.recordError(StateError(_private), null), isNull);
      fail = false;
      expect(await service.recordError(StateError(_private), null), isNotNull);
      expect(await service.getAllReports(), hasLength(1));
      _expectSafe(await current.readAsString());
    },
  );

  test(
    'Web storage, JSON, clipboard and export share the same privacy policy',
    () async {
      final service = web.CrashReportService.forTesting();
      await service.initialize();
      service.currentRoute = _path;
      final report = await service.recordError(
        _PrivateError(),
        StackTrace.fromString(_private),
        context: _email,
        additionalData: {
          'errorSource': 'zone',
          'nested': {
            'secret': [_private, _email, _path],
          },
        },
      );
      expect(report, isNotNull);
      expect(report!.additionalData, {'errorSource': 'zone'});
      _expectSafe(jsonEncode((await service.getAllReports()).single.toJson()));
      _expectSafe(await service.exportAllReports());
      await service.copyReportToClipboard(report);
      _expectSafe(clipboardText!);
      for (var i = 0; i < 15; i++) {
        await service.recordError(StateError(_private), null);
      }
      expect(await service.getReportCount(), 10);
      _expectSafe(await service.exportAllReports());
    },
  );

  test('iOS private-storage legacy root is migrated and anonymized', () async {
    final privateRoot = await Directory(
      p.join(supportDir.path, 'PrivateShelf'),
    ).create();
    final privateLegacy = File(p.join(privateRoot.path, 'crash_reports.json'));
    final pending = File('${privateLegacy.path}.tmp');
    await privateLegacy.writeAsString(jsonEncode([_legacyReport()]));
    await pending.writeAsString(jsonEncode([_legacyReport(number: 1)]));
    final service = CrashReportService.forTesting(
      privateDirectory: () async => privateRoot,
    );
    await service.initialize();
    expect(await service.getAllReports(), hasLength(1));
    expect(await privateLegacy.exists(), isTrue);
    _expectSafe(await privateLegacy.readAsString());
    _expectSafe(await pending.readAsString());
    expect(
      (jsonDecode(await privateLegacy.readAsString())
          as Map)['migrationVersion'],
      1,
    );
  });

  test(
    'explicit delete removes one record from current, legacy and staging copies',
    () async {
      await current.parent.create(recursive: true);
      final privateRoot = await Directory(
        p.join(supportDir.path, 'PrivateShelf'),
      ).create();
      final privateLegacy = File(
        p.join(privateRoot.path, 'crash_reports.json'),
      );
      final first = _legacyReport();
      final other = _legacyReport(number: 1)..['errorType'] = 'StateError';
      final files = [
        current,
        legacy,
        privateLegacy,
        File('${current.path}.tmp'),
        File('${legacy.path}.privacy-synthetic.tmp'),
        File('${privateLegacy.path}.tmp'),
      ];
      for (final file in files) {
        await file.writeAsString(jsonEncode([first, other]));
      }
      final id = CrashReport.fromJson(first).id;
      var fail = true;
      final service = CrashReportService.forTesting(
        privateDirectory: () async => privateRoot,
        beforeReplace: (_, destination) async {
          if (destination.path == legacy.path && fail) {
            throw const FileSystemException(
              'Synthetic delete publication failure',
            );
          }
        },
      );
      await expectLater(
        service.deleteReport(id),
        throwsA(isA<FileSystemException>()),
      );
      expect(await legacy.readAsString(), contains(first['id']));
      fail = false;
      await service.deleteReport(id);
      for (final directory in [current.parent, docsDir, privateRoot]) {
        await for (final file in directory.list()) {
          if (file is! File) continue;
          final contents = await file.readAsString();
          _expectSafe(contents);
          expect(contents, isNot(contains(id)));
          expect(contents, isNot(contains(first['timestamp'])));
          expect(contents, isNot(contains('FileSystemException')));
          expect(contents, contains(CrashReport.fromJson(other).id));
        }
      }
      await service.initialize();
      expect(await service.getAllReports(), hasLength(1));
    },
  );

  test(
    'explicit clear removes corrupt, migrated and pending physical metadata',
    () async {
      await current.parent.create(recursive: true);
      final privateRoot = await Directory(
        p.join(supportDir.path, 'PrivateShelf'),
      ).create();
      final privateLegacy = File(
        p.join(privateRoot.path, 'crash_reports.json'),
      );
      final files = [
        current,
        legacy,
        privateLegacy,
        File('${current.path}.tmp'),
        File('${legacy.path}.privacy-synthetic.tmp'),
        File('${privateLegacy.path}.tmp.tmp'),
      ];
      for (final file in files) {
        await file.writeAsString('corrupt $_private metadata');
      }
      final service = CrashReportService.forTesting(
        privateDirectory: () async => privateRoot,
      );
      await service.clearAllReports();
      for (final file in files) {
        expect(await file.exists(), isFalse);
      }
      await service.initialize();
      expect(await service.getAllReports(), isEmpty);
    },
  );

  test('reentrant error fallback never prints the raw nested error', () {
    final originalPrint = debugPrint;
    final messages = <String>[];
    var reentered = false;
    GlobalErrorHandler.setCrashReportEnabled(false);
    try {
      debugPrint = (String? message, {int? wrapWidth}) {
        messages.add(message ?? '');
        if (!reentered) {
          reentered = true;
          GlobalErrorHandler.log(StateError(_private), null);
        }
      };
      GlobalErrorHandler.log(StateError('Synthetic outer error'), null);
    } finally {
      debugPrint = originalPrint;
      GlobalErrorHandler.setCrashReportEnabled(true);
    }
    expect(messages, contains('Error in error handler.'));
    _expectSafe(messages.join('\n'));
  });
}
