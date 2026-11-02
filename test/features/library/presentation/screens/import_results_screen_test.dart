import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/features/library/data/repositories/isar_media_repository.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/import_execution_report.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/presentation/screens/import_results_screen.dart';
import 'package:private_shelf/features/library/presentation/providers/import_result_revision_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends Mock implements MediaRepository {}

class _Isar extends Mock implements Isar {}

const _previewFont = String.fromEnvironment('UX_QA_FONT');
const _previewIcons = String.fromEnvironment('UX_QA_ICON_FONT');
const _previewBoundary = ValueKey('import-read-retry-preview');
const _readFailedJa = '追加した項目の情報を読み込めませんでした';
const _readFailedEn = "Couldn't load the added items' information.";
const _checkingJa = '項目の情報を読み込み中';
const _reference = ImportCommittedItem(
  id: 1,
  path: 'library/private-source.jpg',
  sourcePath: 'original-private-source.jpg',
);

MediaItem _file(ImportCommittedItem reference) => MediaItem()
  ..id = reference.id
  ..uid = reference.uid
  ..path = reference.path
  ..parentPath = 'library'
  ..type = MediaType.file;

ProviderContainer _container(
  MediaRepository repository, {
  Stream<int>? revision,
}) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      mediaRepositoryProvider.overrideWith((ref) async => repository),
      importResultRevisionProvider.overrideWith(
        (ref) => revision ?? const Stream<int>.empty(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _subject(
  ProviderContainer container, {
  List<ImportCommittedItem> items = const [_reference],
  String locale = 'ja',
  bool dark = false,
  double textScale = 1,
}) {
  var theme = dark ? AppTheme.dark : AppTheme.light;
  if (_previewFont.isNotEmpty) {
    final buttonStyle = theme.outlinedButtonTheme.style;
    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'UxPreview'),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
          fontFamily: 'UxPreview',
        ),
        toolbarTextStyle: theme.appBarTheme.toolbarTextStyle?.copyWith(
          fontFamily: 'UxPreview',
        ),
      ),
      listTileTheme: theme.listTileTheme.copyWith(
        titleTextStyle: theme.listTileTheme.titleTextStyle?.copyWith(
          fontFamily: 'UxPreview',
        ),
        subtitleTextStyle: theme.listTileTheme.subtitleTextStyle?.copyWith(
          fontFamily: 'UxPreview',
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: (buttonStyle ?? const ButtonStyle()).copyWith(
          textStyle: WidgetStatePropertyAll(
            (buttonStyle?.textStyle?.resolve({}) ?? const TextStyle()).copyWith(
              fontFamily: 'UxPreview',
            ),
          ),
        ),
      ),
    );
  }
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: theme,
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: _previewBoundary,
        child: ImportResultsScreen(items: items),
      ),
    ),
  );
}

Finder _reload([String locale = 'ja']) =>
    find.widgetWithText(OutlinedButton, locale == 'ja' ? '再読み込み' : 'Reload');

void main() {
  setUpAll(() async {
    registerFallbackValue(MediaItem());
    for (final font in [
      ('UxPreview', _previewFont),
      ('MaterialIcons', _previewIcons),
    ]) {
      if (font.$2.isEmpty) continue;
      final loader = FontLoader(font.$1);
      loader.addFont(File(font.$2).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  late _Repository repository;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _Repository();
    when(
      () => repository.getCollectionByPath(any()),
    ).thenAnswer((_) async => Result.success(null));
  });
  const reference = ImportCommittedItem(
    id: 1,
    path: 'library/photo.jpg',
    sourcePath: 'photo.jpg',
  );

  test('library sentinel is valid without a database folder item', () async {
    final item = MediaItem()
      ..id = 1
      ..path = reference.path
      ..parentPath = 'library';
    when(
      () => repository.getById(1),
    ).thenAnswer((_) async => Result.success(item));
    expect(await resolveImportedItem(repository, reference), same(item));
    verifyNever(() => repository.getByPath(any(), includeTrashed: true));
  });

  test('hidden ancestor prevents exposing a committed filename', () async {
    final item = MediaItem()
      ..id = 1
      ..path = reference.path
      ..parentPath = 'library/private';
    final parent = MediaItem()
      ..id = 2
      ..path = 'library/private'
      ..isHidden = true;
    when(
      () => repository.getById(1),
    ).thenAnswer((_) async => Result.success(item));
    when(
      () => repository.getByPath('library/private', includeTrashed: true),
    ).thenAnswer((_) async => Result.success(parent));
    expect(await resolveImportedItem(repository, reference), isNull);
  });

  test(
    'hidden root catalog is checked before accepting root sentinel',
    () async {
      final item = MediaItem()
        ..id = 1
        ..path = reference.path
        ..parentPath = 'library';
      final root = MediaCollection()
        ..path = 'library'
        ..isHidden = true;
      when(
        () => repository.getById(1),
      ).thenAnswer((_) async => Result.success(item));
      when(
        () => repository.getCollectionByPath('library'),
      ).thenAnswer((_) async => Result.success(root));
      expect(await resolveImportedItem(repository, reference), isNull);
    },
  );

  test(
    'unidentified reused numeric ID does not resolve a different file',
    () async {
      when(() => repository.getById(1)).thenAnswer(
        (_) async => Result.success(
          MediaItem()
            ..id = 1
            ..path = 'library/replacement.jpg',
        ),
      );
      expect(await resolveImportedItem(repository, reference), isNull);
    },
  );

  test(
    'stable UID follows a moved file but still applies hidden protection',
    () async {
      final item = MediaItem()
        ..id = 9
        ..uid = 'stable'
        ..path = 'library/moved.jpg';
      when(
        () => repository.getByUid('stable'),
      ).thenAnswer((_) async => Result.success(item));
      const stableReference = ImportCommittedItem(
        id: 1,
        uid: 'stable',
        path: 'library/photo.jpg',
        sourcePath: 'photo.jpg',
      );
      expect(
        await resolveImportedItem(repository, stableReference),
        same(item),
      );
      item.isHidden = true;
      expect(await resolveImportedItem(repository, stableReference), isNull);
    },
  );

  testWidgets('row read failure reloads the same item without reimporting', (
    tester,
  ) async {
    var reads = 0;
    final recovered = _file(_reference);
    when(() => repository.getById(1)).thenAnswer((_) async {
      reads++;
      return reads == 1
          ? Result.failure(AppError.database('private technical path'))
          : Result.success(recovered);
    });
    await tester.pumpWidget(_subject(_container(repository)));
    await tester.pumpAndSettle();
    expect(find.text(_readFailedJa), findsOneWidget);
    expect(find.textContaining('private-source.jpg'), findsNothing);
    expect(find.textContaining('private technical path'), findsNothing);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ImportResultsScreen)),
    )!;
    expect(find.text(l10n.importResultsUnavailable), findsNothing);
    expect(find.text(l10n.errorDatabase), findsNothing);

    await tester.tap(_reload());
    await tester.pumpAndSettle();
    expect(find.text('private-source.jpg'), findsOneWidget);
    expect(find.text(_readFailedJa), findsNothing);
    expect(_reload(), findsNothing);
    expect(reads, 2);
    verifyNever(() => repository.save(any()));
  });

  testWidgets('repeated row failure keeps another reload available', (
    tester,
  ) async {
    var reads = 0;
    when(() => repository.getById(1)).thenAnswer((_) async {
      reads++;
      return Result.failure(AppError.database('sensitive filename.jpg'));
    });
    await tester.pumpWidget(_subject(_container(repository)));
    await tester.pumpAndSettle();
    for (var retry = 0; retry < 2; retry++) {
      await tester.tap(_reload());
      await tester.pumpAndSettle();
      expect(find.text(_readFailedJa), findsOneWidget);
      expect(_reload().hitTestable(), findsOneWidget);
      expect(find.textContaining('sensitive filename.jpg'), findsNothing);
    }
    expect(reads, 3);
    verifyNever(() => repository.save(any()));
  });

  for (final outcome in ['missing', 'hidden parent']) {
    testWidgets('reload to $outcome gives unavailable without exposing names', (
      tester,
    ) async {
      var reads = 0;
      final item = _file(_reference)..parentPath = 'library/private';
      when(() => repository.getById(1)).thenAnswer((_) async {
        reads++;
        if (reads == 1) {
          return Result.failure(AppError.database('read unavailable'));
        }
        return Result.success(outcome == 'missing' ? null : item);
      });
      when(
        () => repository.getByPath('library/private', includeTrashed: true),
      ).thenAnswer(
        (_) async => Result.success(
          MediaItem()
            ..id = 8
            ..path = 'library/private'
            ..isHidden = true,
        ),
      );
      await tester.pumpWidget(_subject(_container(repository)));
      await tester.pumpAndSettle();
      await tester.tap(_reload());
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ImportResultsScreen)),
      )!;
      expect(find.text(l10n.importResultsUnavailable), findsOneWidget);
      expect(_reload(), findsNothing);
      expect(find.text(_readFailedJa), findsNothing);
      expect(find.textContaining('private-source.jpg'), findsNothing);
      expect(reads, 2);
    });
  }

  testWidgets(
    'pending row reload rejects repeat activation and keeps good rows',
    (tester) async {
      const another = ImportCommittedItem(
        id: 2,
        path: 'library/ready.jpg',
        sourcePath: 'ready.jpg',
      );
      final pending = Completer<Result<MediaItem?, AppError>>();
      var failedReads = 0;
      var readyReads = 0;
      when(() => repository.getById(1)).thenAnswer((_) {
        failedReads++;
        return failedReads == 1
            ? Future.value(Result.failure(AppError.database('temporary')))
            : pending.future;
      });
      when(() => repository.getById(2)).thenAnswer((_) async {
        readyReads++;
        return Result.success(_file(another));
      });
      await tester.pumpWidget(
        _subject(_container(repository), items: const [_reference, another]),
      );
      await tester.pumpAndSettle();
      final retry = tester.widget<OutlinedButton>(_reload()).onPressed!;
      retry();
      retry();
      await tester.pump();
      expect(failedReads, 2);
      expect(readyReads, 1);
      expect(find.text('ready.jpg'), findsOneWidget);
      expect(find.text('private-source.jpg'), findsNothing);
      expect(_reload(), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .semanticsLabel,
        _checkingJa,
      );
      pending.complete(Result.success(_file(_reference)));
      await tester.pumpAndSettle();
      expect(find.text('private-source.jpg'), findsOneWidget);
      expect(find.text('ready.jpg'), findsOneWidget);
      expect(readyReads, 1);
    },
  );

  testWidgets(
    'metadata revision hides previously ready names while rechecking',
    (tester) async {
      final revisions = StreamController<int>();
      addTearDown(revisions.close);
      final pending = Completer<Result<MediaItem?, AppError>>();
      var reads = 0;
      when(() => repository.getById(1)).thenAnswer((_) {
        reads++;
        return reads == 1
            ? Future.value(Result.success(_file(_reference)))
            : pending.future;
      });
      await tester.pumpWidget(
        _subject(_container(repository, revision: revisions.stream)),
      );
      await tester.pumpAndSettle();
      expect(find.text('private-source.jpg'), findsOneWidget);
      revisions.add(1);
      await tester.pump();
      await tester.pump();
      expect(reads, 2);
      expect(find.text('private-source.jpg'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(Result.success(_file(_reference)..isHidden = true));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ImportResultsScreen)),
      )!;
      expect(find.text(l10n.importResultsUnavailable), findsOneWidget);
      expect(find.text('private-source.jpg'), findsNothing);
    },
  );

  testWidgets('same numeric row key rechecks when the committed UID changes', (
    tester,
  ) async {
    const original = ImportCommittedItem(
      id: 1,
      uid: 'original',
      path: 'library/original.jpg',
      sourcePath: 'original.jpg',
    );
    const replacement = ImportCommittedItem(
      id: 1,
      uid: 'replacement',
      path: 'library/replacement.jpg',
      sourcePath: 'replacement.jpg',
    );
    final pending = Completer<Result<MediaItem?, AppError>>();
    when(
      () => repository.getByUid('original'),
    ).thenAnswer((_) async => Result.success(_file(original)));
    when(
      () => repository.getByUid('replacement'),
    ).thenAnswer((_) => pending.future);
    final container = _container(repository);
    await tester.pumpWidget(_subject(container, items: const [original]));
    await tester.pumpAndSettle();
    expect(find.text('original.jpg'), findsOneWidget);
    await tester.pumpWidget(_subject(container, items: const [replacement]));
    await tester.pump();
    expect(find.text('original.jpg'), findsNothing);
    expect(find.text('replacement.jpg'), findsNothing);
    pending.complete(Result.success(_file(replacement)));
    await tester.pumpAndSettle();
    expect(find.text('replacement.jpg'), findsOneWidget);
    verify(() => repository.getByUid('original')).called(1);
    verify(() => repository.getByUid('replacement')).called(1);
  });

  testWidgets(
    'repository replacement rechecks rows against the new repository',
    (tester) async {
      final replacement = _Repository();
      final pending = Completer<Result<MediaItem?, AppError>>();
      when(
        () => repository.getById(1),
      ).thenAnswer((_) async => Result.success(_file(_reference)));
      when(() => replacement.getById(1)).thenAnswer((_) => pending.future);
      var current = repository;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          mediaRepositoryProvider.overrideWith((ref) async => current),
          importResultRevisionProvider.overrideWith(
            (ref) => const Stream<int>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_subject(container));
      await tester.pumpAndSettle();
      expect(find.text('private-source.jpg'), findsOneWidget);
      current = replacement;
      container.invalidate(mediaRepositoryProvider);
      await tester.pump();
      await tester.pump();
      expect(find.text('private-source.jpg'), findsNothing);
      pending.complete(Result.success(null));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ImportResultsScreen)),
      )!;
      expect(find.text(l10n.importResultsUnavailable), findsOneWidget);
      verify(() => replacement.getById(1)).called(1);
    },
  );

  for (final staleOutcome in ['success', 'failure']) {
    testWidgets(
      'revision supersedes pending retry $staleOutcome without changing latest result',
      (tester) async {
        final revisions = StreamController<int>();
        addTearDown(revisions.close);
        final retryRead = Completer<Result<MediaItem?, AppError>>();
        var reads = 0;
        when(() => repository.getById(1)).thenAnswer((_) {
          reads++;
          return switch (reads) {
            1 => Future.value(Result.failure(AppError.database('first read'))),
            2 => retryRead.future,
            _ => Future.value(Result.success(null)),
          };
        });
        await tester.pumpWidget(
          _subject(_container(repository, revision: revisions.stream)),
        );
        await tester.pumpAndSettle();
        await tester.tap(_reload());
        await tester.pump();
        revisions.add(1);
        await tester.pumpAndSettle();
        expect(reads, 3);
        retryRead.complete(
          staleOutcome == 'success'
              ? Result.success(_file(_reference))
              : Result.failure(AppError.database('superseded request failed')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ImportResultsScreen)),
        )!;
        expect(find.text(l10n.importResultsUnavailable), findsOneWidget);
        expect(find.text('private-source.jpg'), findsNothing);
      },
    );
  }

  testWidgets(
    'revision replaces retry before builder subscribes and consumes its late failure',
    (tester) async {
      final revisions = StreamController<int>();
      addTearDown(revisions.close);
      final retryRead = Completer<Result<MediaItem?, AppError>>();
      var reads = 0;
      when(() => repository.getById(1)).thenAnswer((_) {
        reads++;
        return switch (reads) {
          1 => Future.value(Result.failure(AppError.database('first read'))),
          2 => retryRead.future,
          _ => Future.value(Result.success(null)),
        };
      });
      await tester.pumpWidget(
        _subject(_container(repository, revision: revisions.stream)),
      );
      await tester.pumpAndSettle();
      final retry = tester.widget<OutlinedButton>(_reload()).onPressed!;

      // Deliberately do not pump: the new retry future has no FutureBuilder
      // subscription when a metadata event replaces it.
      retry();
      expect(reads, 2);
      revisions.add(1);
      await tester.idle();
      expect(reads, 3);
      expect(find.text(_readFailedJa), findsOneWidget);
      expect(_reload(), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      retryRead.complete(
        Result.failure(AppError.database('unsubscribed retry failed')),
      );
      await tester.idle();
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ImportResultsScreen)),
      )!;
      expect(find.text(l10n.importResultsUnavailable), findsOneWidget);
      expect(find.text(_readFailedJa), findsNothing);
      expect(find.text('private-source.jpg'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'global failure can reload and ignores repeated pending activation',
    (tester) async {
      final pending = Completer<MediaRepository>();
      var initializations = 0;
      when(
        () => repository.getById(1),
      ).thenAnswer((_) async => Result.success(_file(_reference)));
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          mediaRepositoryProvider.overrideWith((ref) {
            initializations++;
            if (initializations == 1) throw AppError.database('private path');
            return pending.future;
          }),
          importResultRevisionProvider.overrideWith(
            (ref) => const Stream<int>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_subject(container));
      await tester.pumpAndSettle();
      expect(find.text(_readFailedJa), findsOneWidget);
      expect(find.textContaining('private path'), findsNothing);
      final retry = tester.widget<OutlinedButton>(_reload()).onPressed!;
      retry();
      retry();
      await tester.pump();
      expect(initializations, 2);
      expect(find.text(_readFailedJa), findsNothing);
      expect(_reload(), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .semanticsLabel,
        _checkingJa,
      );
      pending.complete(repository);
      await tester.pumpAndSettle();
      expect(find.text('private-source.jpg'), findsOneWidget);
      expect(initializations, 2);
      expect(container.exists(isarProvider), isFalse);
      expect(container.exists(sharedPreferencesProvider), isFalse);
    },
  );

  testWidgets('global repeated initialization failure returns to reload', (
    tester,
  ) async {
    var initializations = 0;
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        mediaRepositoryProvider.overrideWith((ref) async {
          initializations++;
          throw AppError.database('internal initialization details');
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_subject(container));
    await tester.pumpAndSettle();
    for (var retry = 0; retry < 2; retry++) {
      await tester.tap(_reload());
      await tester.pumpAndSettle();
      expect(find.text(_readFailedJa), findsOneWidget);
      expect(_reload().hitTestable(), findsOneWidget);
    }
    expect(initializations, 3);
  });

  testWidgets(
    'reload retries failed Isar and retained failed preferences through real media factory',
    (tester) async {
      final database = _Isar();
      final preferences = await SharedPreferences.getInstance();
      var prefInitializations = 0;
      var dbInitializations = 0;
      var mayRecover = false;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) async {
            prefInitializations++;
            if (!mayRecover) throw StateError('preferences unavailable');
            return preferences;
          }),
          isarProvider.overrideWith((ref) async {
            dbInitializations++;
            // Match the production factory's dependency mode: it reads preferences.
            await ref.read(sharedPreferencesProvider.future);
            return database;
          }),
        ],
      );
      addTearDown(container.dispose);
      // Keep the failure alive as another screen's preferences consumer can do.
      final prefListener = container.listen(
        sharedPreferencesProvider,
        (_, _) {},
      );
      addTearDown(prefListener.close);
      await tester.pumpWidget(_subject(container, items: const []));
      await tester.pumpAndSettle();
      expect(container.read(isarProvider).hasError, isTrue);
      expect(container.read(sharedPreferencesProvider).hasError, isTrue);
      expect(prefInitializations, 1);
      expect(dbInitializations, 1);
      mayRecover = true;
      await tester.tap(_reload());
      await tester.pumpAndSettle();
      expect(find.text(_readFailedJa), findsNothing);
      expect(prefInitializations, 2);
      expect(dbInitializations, 2);
      expect(container.read(isarProvider).value, same(database));
      expect(
        container.read(sharedPreferencesProvider).value,
        same(preferences),
      );
      expect(
        container.read(mediaRepositoryProvider).value,
        isA<IsarMediaRepository>(),
      );
      verifyNever(
        () => database.close(deleteFromDisk: any(named: 'deleteFromDisk')),
      );
    },
  );

  testWidgets('failed Isar retries without rebuilding healthy preferences', (
    tester,
  ) async {
    final database = _Isar();
    final preferences = await SharedPreferences.getInstance();
    var prefInitializations = 0;
    var dbInitializations = 0;
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) async {
          prefInitializations++;
          return preferences;
        }),
        isarProvider.overrideWith((ref) async {
          dbInitializations++;
          await ref.read(sharedPreferencesProvider.future);
          if (dbInitializations == 1) {
            throw StateError('temporary database failure');
          }
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);
    final prefListener = container.listen(sharedPreferencesProvider, (_, _) {});
    addTearDown(prefListener.close);
    await tester.pumpWidget(_subject(container, items: const []));
    await tester.pumpAndSettle();
    expect(container.read(isarProvider).hasError, isTrue);
    expect(container.read(sharedPreferencesProvider).hasValue, isTrue);
    await tester.tap(_reload());
    await tester.pumpAndSettle();
    expect(dbInitializations, 2);
    expect(prefInitializations, 1);
    expect(
      container.read(mediaRepositoryProvider).value,
      isA<IsarMediaRepository>(),
    );
  });

  testWidgets(
    'repository-only failure preserves healthy database and preferences',
    (tester) async {
      final database = _Isar();
      final preferences = await SharedPreferences.getInstance();
      var prefInitializations = 0;
      var dbInitializations = 0;
      var repoInitializations = 0;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) async {
            prefInitializations++;
            return preferences;
          }),
          isarProvider.overrideWith((ref) async {
            dbInitializations++;
            await ref.read(sharedPreferencesProvider.future);
            return database;
          }),
          mediaRepositoryProvider.overrideWith((ref) async {
            repoInitializations++;
            await ref.watch(isarProvider.future);
            if (repoInitializations == 1) {
              throw StateError('repository setup failure');
            }
            return repository;
          }),
        ],
      );
      addTearDown(container.dispose);
      final prefListener = container.listen(
        sharedPreferencesProvider,
        (_, _) {},
      );
      addTearDown(prefListener.close);
      await tester.pumpWidget(_subject(container, items: const []));
      await tester.pumpAndSettle();
      expect(find.text(_readFailedJa), findsOneWidget);
      await tester.tap(_reload());
      await tester.pumpAndSettle();
      expect(repoInitializations, 2);
      expect(dbInitializations, 1);
      expect(prefInitializations, 1);
      expect(container.read(isarProvider).value, same(database));
      expect(
        container.read(sharedPreferencesProvider).value,
        same(preferences),
      );
    },
  );

  for (final locale in ['ja', 'en']) {
    for (final dark in [false, true]) {
      for (final global in [false, true]) {
        testWidgets(
          '$locale ${dark ? 'dark' : 'light'} ${global ? 'global' : 'row'} error at 320dp 200% has reachable reload',
          (tester) async {
            tester.view.physicalSize = const Size(320, 568);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            when(() => repository.getById(1)).thenAnswer(
              (_) async => Result.failure(AppError.database('not for display')),
            );
            final container = global
                ? ProviderContainer(
                    retry: (_, _) => null,
                    overrides: [
                      mediaRepositoryProvider.overrideWith((ref) async {
                        throw AppError.database('not for display');
                      }),
                    ],
                  )
                : _container(repository);
            if (global) addTearDown(container.dispose);
            await tester.pumpWidget(
              _subject(container, locale: locale, dark: dark, textScale: 2),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.text(locale == 'ja' ? _readFailedJa : _readFailedEn),
              findsOneWidget,
            );
            await tester.ensureVisible(_reload(locale));
            expect(_reload(locale).hitTestable(), findsOneWidget);
            expect(
              tester.getSize(_reload(locale)).height,
              greaterThanOrEqualTo(48),
            );
            expect(
              tester.getSize(_reload(locale)).width,
              greaterThanOrEqualTo(48),
            );
            await tester.tap(_reload(locale));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(_reload(locale), findsOneWidget);
          },
        );
      }
    }
  }

  testWidgets('import information read error representative preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const readyReference = ImportCommittedItem(
      id: 2,
      path: 'library/旅の写真.jpg',
      sourcePath: '旅の写真.jpg',
    );
    when(() => repository.getById(1)).thenAnswer(
      (_) async => Result.failure(AppError.database('read failure')),
    );
    when(
      () => repository.getById(2),
    ).thenAnswer((_) async => Result.success(_file(readyReference)));
    await tester.pumpWidget(
      _subject(
        _container(repository),
        items: const [readyReference, _reference],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('旅の写真.jpg'), findsOneWidget);
    expect(find.text(_readFailedJa), findsOneWidget);
    expect(_reload().hitTestable(), findsOneWidget);
    if (_previewFont.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_previewBoundary),
    );
    await tester.runAsync(() async {
      final captured = await boundary.toImage(pixelRatio: 1);
      try {
        final data = await captured.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/ux_review');
        await directory.create(recursive: true);
        await File('${directory.path}/import-read-retry-ja.png').writeAsBytes(
          data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      } finally {
        captured.dispose();
      }
    });
  });
}
