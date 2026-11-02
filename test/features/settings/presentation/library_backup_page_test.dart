import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import '../../../helpers/picker_test_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:private_shelf/features/library/data/services/library_backup_service.dart';
import 'package:private_shelf/features/library/domain/models/library_backup.dart';
import 'package:private_shelf/features/settings/presentation/library_backup_page.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class _Service extends Mock implements LibraryBackupService {}

class _Picker extends Mock
    with MockPlatformInterfaceMixin
    implements FilePickerPlatform {}

void main() {
  late _Service service;
  late _Picker picker;
  late PreparedLibraryBackup prepared;
  final chosen = File('/tmp/chosen.tagshelf');

  PreparedLibraryBackup preview({Future<void> Function()? dispose}) =>
      PreparedLibraryBackup(
        directory: Directory('/tmp/private-preview'),
        document: {
          'items': [],
          'collections': [],
          'tags': [
            {'name': 'Travel'},
          ],
        },
        createdAt: DateTime(2026, 10, 2),
        fileCount: 2,
        totalBytes: 2048,
        disposeStaging: dispose ?? () async {},
      );

  setUpAll(() {
    registerFallbackValue(File('/tmp/fallback.tagshelf'));
    registerFallbackValue(preview());
  });
  setUp(() {
    service = _Service();
    picker = _Picker();
    prepared = preview();
    FilePickerPlatform.instance = picker;
    when(
      () => picker.pickFile(
        type: FileType.custom,
        allowedExtensions: any(named: 'allowedExtensions'),
      ),
    ).thenAnswer(
      (_) async => PickerTestFile(
        name: 'chosen.tagshelf',
        uri: Uri.file(chosen.path),
        knownLength: 2048,
      ),
    );
    when(
      () => picker.getDirectoryPath(dialogTitle: any(named: 'dialogTitle')),
    ).thenAnswer((_) async => null);
    when(
      () => service.prepareRestore(
        any(),
        cancellation: any(named: 'cancellation'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => prepared);
    when(() => service.disposeExport(any())).thenAnswer((_) async {});
    when(
      () => service.restore(
        any(),
        cancellation: any(named: 'cancellation'),
        folderName: any(named: 'folderName'),
      ),
    ).thenAnswer(
      (_) async => const LibraryRestoreResult(addedItems: 2, skippedItems: 1),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryBackupServiceProvider.overrideWith((ref) async => service),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LibraryBackupPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  for (final unsupportedUri in [false, true]) {
    testWidgets(
      'single backup picker safely handles ${unsupportedUri ? 'non-local URI' : 'cancellation'}',
      (tester) async {
        when(
          () => picker.pickFile(
            type: FileType.custom,
            allowedExtensions: any(named: 'allowedExtensions'),
          ),
        ).thenAnswer(
          (_) async => unsupportedUri
              ? PickerTestFile(
                  name: 'synthetic.tagshelf',
                  uri: Uri.parse('content://synthetic/42'),
                )
              : null,
        );
        await pump(tester);
        await tap(tester, 'Restore from backup');
        expect(find.text('Review restore'), findsNothing);
        verifyNever(
          () => service.prepareRestore(
            any(),
            cancellation: any(named: 'cancellation'),
            onProgress: any(named: 'onProgress'),
          ),
        );
        verifyNever(
          () => service.restore(
            any(),
            cancellation: any(named: 'cancellation'),
            folderName: any(named: 'folderName'),
          ),
        );
      },
    );
  }

  testWidgets(
    'rapid export taps start only one operation and cancelled destination disposes private archive',
    (tester) async {
      final operation = Completer<File>();
      when(
        () => service.createBackup(
          cancellation: any(named: 'cancellation'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) => operation.future);
      await pump(tester);
      expect(find.textContaining('not encrypted'), findsOneWidget);
      await tester.ensureVisible(find.text('Save backup'));
      await tester.tap(find.text('Save backup'));
      await tester.tap(find.text('Save backup'));
      await tester.pump();
      verify(
        () => service.createBackup(
          cancellation: any(named: 'cancellation'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
      operation.complete(chosen);
      await tester.pumpAndSettle();
      verify(() => service.disposeExport(chosen)).called(1);
      expect(find.text('Backup saved'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'restore preview never imports until confirmed; cancellation returns safely',
    (tester) async {
      await pump(tester);
      await tap(tester, 'Restore from backup');
      expect(find.text('Review restore'), findsOneWidget);
      expect(find.textContaining('2 files'), findsOneWidget);
      verifyNever(
        () => service.restore(
          any(),
          cancellation: any(named: 'cancellation'),
          folderName: any(named: 'folderName'),
        ),
      );
      await tap(tester, 'Return without adding');
      expect(find.text('Review restore'), findsNothing);
      verifyNever(
        () => service.restore(
          any(),
          cancellation: any(named: 'cancellation'),
          folderName: any(named: 'folderName'),
        ),
      );
    },
  );

  testWidgets(
    'commit failure keeps the chosen file for retry and requires confirmation again',
    (tester) async {
      when(
        () => service.restore(
          any(),
          cancellation: any(named: 'cancellation'),
          folderName: any(named: 'folderName'),
        ),
      ).thenAnswer((_) async {
        throw const FileSystemException('disk full');
      });
      await pump(tester);
      await tap(tester, 'Restore from backup');
      await tap(tester, 'Add this backup to my library');
      expect(find.text('Retry'), findsOneWidget);
      await tap(tester, 'Retry');
      expect(find.text('Review restore'), findsOneWidget);
      verify(
        () => picker.pickFile(
          type: FileType.custom,
          allowedExtensions: any(named: 'allowedExtensions'),
        ),
      ).called(1);
      final validations = verify(
        () => service.prepareRestore(
          captureAny(),
          cancellation: any(named: 'cancellation'),
          onProgress: any(named: 'onProgress'),
        ),
      );
      validations.called(2);
      expect(
        validations.captured.cast<File>().map((file) => file.path).toList(),
        [chosen.path, chosen.path],
      );
      verify(
        () => service.restore(
          any(),
          cancellation: any(named: 'cancellation'),
          folderName: any(named: 'folderName'),
        ),
      ).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'committed cleanup warning preserves success and usable actions',
    (tester) async {
      var disposals = 0;
      prepared = preview(
        dispose: () async {
          disposals++;
          throw const FileSystemException('cleanup unavailable');
        },
      );
      when(
        () => service.restore(
          any(),
          cancellation: any(named: 'cancellation'),
          folderName: any(named: 'folderName'),
        ),
      ).thenAnswer(
        (_) async => const LibraryRestoreResult(
          addedItems: 2,
          skippedItems: 1,
          cleanupIncomplete: true,
        ),
      );
      await pump(tester);
      await tap(tester, 'Restore from backup');
      await tap(tester, 'Add this backup to my library');
      expect(
        find.text('Restored. Added 2 items; kept 1 existing items.'),
        findsOneWidget,
      );
      expect(find.textContaining('Restoration is complete.'), findsOneWidget);
      expect(find.textContaining('Could not complete'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(disposals, 0); // committed service already attempted cleanup
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('Save backup'),
                matching: find.byWidgetPredicate(
                  (widget) => widget is FilledButton,
                ),
              ),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'capacity failure during preview is retryable without calling it a damaged backup',
    (tester) async {
      var attempts = 0;
      when(
        () => service.prepareRestore(
          any(),
          cancellation: any(named: 'cancellation'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async {
        if (attempts++ == 0) throw const FileSystemException('no space');
        return prepared;
      });
      await pump(tester);
      await tap(tester, 'Restore from backup');
      expect(find.textContaining('Could not verify'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      await tap(tester, 'Retry');
      expect(find.text('Review restore'), findsOneWidget);
      verify(
        () => picker.pickFile(
          type: FileType.custom,
          allowedExtensions: any(named: 'allowedExtensions'),
        ),
      ).called(1);
      verifyNever(
        () => service.restore(
          any(),
          cancellation: any(named: 'cancellation'),
          folderName: any(named: 'folderName'),
        ),
      );
    },
  );

  testWidgets('preview cleanup failure stays usable and can be retried', (
    tester,
  ) async {
    var attempts = 0;
    prepared = preview(
      dispose: () async {
        if (attempts++ == 0) {
          throw const FileSystemException('temporary cleanup failure');
        }
      },
    );
    await pump(tester);
    await tap(tester, 'Restore from backup');
    await tap(tester, 'Return without adding');
    expect(find.text('Review restore'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tap(tester, 'Return without adding');
    expect(find.text('Review restore'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
