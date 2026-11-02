import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/debug/features/crash_log_viewer_feature.dart';
import 'package:private_shelf/core/error/crash_report_model.dart';
import 'package:private_shelf/core/error/crash_report_service.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class _ViewerService extends CrashReportService {
  _ViewerService() : super.forTesting();

  bool failLoad = true;
  int clearCalls = 0;

  @override
  Future<List<CrashReport>> getAllReports() async {
    if (failLoad) {
      throw const FormatException('SYNTHETIC_PRIVATE_ERROR');
    }
    return [];
  }

  @override
  Future<void> clearAllReports() async {
    clearCalls++;
    failLoad = false;
  }
}

Widget _subject(_ViewerService service) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('ja'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ja'), Locale('en')],
    home: Scaffold(
      body: Builder(
        builder: (context) =>
            CrashLogViewerFeature(service: service).buildPanel(context)!,
      ),
    ),
  ),
);

void main() {
  testWidgets('failed log loading exits loading state and permits retry', (
    tester,
  ) async {
    final service = _ViewerService();
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('データの保存や読み込みに失敗しました'), findsOneWidget);
    expect(find.textContaining('SYNTHETIC_PRIVATE_ERROR'), findsNothing);
    expect(tester.takeException(), isNull);
    service.failLoad = false;
    await tester.tap(find.text('再試行'));
    await tester.pumpAndSettle();
    expect(find.text('クラッシュレポートはありません'), findsOneWidget);
  });

  testWidgets('failed log loading still permits confirmed explicit clearing', (
    tester,
  ) async {
    final service = _ViewerService();
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(service.clearCalls, 0);
    await tester.tap(find.widgetWithText(TextButton, '全て削除'));
    await tester.pumpAndSettle();
    expect(service.clearCalls, 1);
    expect(find.text('クラッシュレポートはありません'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
