import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/core/providers/tab_navigation_provider.dart';
import 'package:private_shelf/core/theme/app_theme.dart';
import 'package:private_shelf/core/utils/date_time_utils.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/resume_banner.dart';
import 'package:private_shelf/features/settings/domain/models/privacy_settings.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _previewFont = String.fromEnvironment('UX_QA_FONT');
const _previewIcons = String.fromEnvironment('UX_QA_ICON_FONT');
const _previewBoundary = ValueKey('resume-preview');
const _open = ValueKey('resume-open');
const _reload = ValueKey('resume-reload');
const _checking = ValueKey('resume-checking');
const _name = ValueKey('resume-name');
const _panel = ValueKey('resume-panel');
const _jaName = '春の家族旅行で何度も見返したい写真と旅の記録をまとめた長いファイル名・先頭が同じ別資料と区別する末尾-A.pdf';
const _enName =
    'Family spring trip photographs and memories with a deliberately long name shared by another document-distinct-ending-A.pdf';
final _mode = StateProvider<AppMode>((ref) => AppMode.internal);

class _MockMediaRepository extends Mock implements MediaRepository {}

class _Secret extends SecretMode {
  @override
  bool build() => false;

  void set(bool value) => state = AsyncData(value);
}

class _Privacy extends PrivacySettingsNotifier {
  _Privacy(this.secretThumbnail);

  final bool secretThumbnail;

  @override
  Future<PrivacySettings> build() async =>
      PrivacySettings(useSecretThumbnailMode: secretThumbnail);
}

MediaCollection _catalog({int itemId = 3, DateTime? viewedAt}) =>
    MediaCollection()
      ..id = 41
      ..path = 'library/catalog'
      ..title = '旅行の記録'
      ..isCatalog = true
      ..type = CollectionType.folder
      ..lastViewedItemId = itemId
      ..lastViewedAt = viewedAt;

MediaItem _file({int id = 3, String name = _jaName}) => MediaItem()
  ..id = id
  ..path = 'library/catalog/$name'
  ..parentPath = 'library/catalog'
  ..type = MediaType.file
  ..sourceType = MediaSourceType.localCopy
  ..updatedAt = DateTime(2000, 1, 1)
  ..size = 9876543;

class _Harness {
  _Harness({
    String fileName = _jaName,
    DateTime? viewedAt,
    bool secretThumbnail = false,
  }) : item = _file(name: fileName),
       collection = ValueNotifier(_catalog(viewedAt: DateTime(2001, 1, 1))),
       freshCatalog = _catalog(viewedAt: viewedAt) {
    readItem = (id) async => Result.success(items[id]);
    items[item.id] = item;
    final folder = MediaItem()
      ..id = 2
      ..path = freshCatalog.path
      ..parentPath = 'library'
      ..type = MediaType.folder;
    when(() => repository.getCollectionById(any())).thenAnswer(
      (invocation) async => Result.success(
        invocation.positionalArguments.first == freshCatalog.id
            ? freshCatalog
            : null,
      ),
    );
    when(
      () => repository.getCollectionByPath(
        any(),
        includeTrashed: any(named: 'includeTrashed'),
      ),
    ).thenAnswer((_) async => Result.success(null));
    when(
      () => repository.getByPath(
        any(),
        includeTrashed: any(named: 'includeTrashed'),
      ),
    ).thenAnswer(
      (invocation) async => Result.success(
        invocation.positionalArguments.first == folder.path ? folder : null,
      ),
    );
    when(() => repository.getById(any())).thenAnswer((invocation) {
      final id = invocation.positionalArguments.first as int;
      itemReads.add(id);
      return readItem(id);
    });
    when(
      () => repository.watchLibraryChanges(filter: any(named: 'filter')),
    ).thenAnswer((_) => const Stream<void>.empty());
    container = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWith((ref) async => repository),
        appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
        appModeProvider.overrideWith((ref) => ref.watch(_mode)),
        secretModeProvider.overrideWith(_Secret.new),
        privacySettingsNotifierProvider.overrideWith(
          () => _Privacy(secretThumbnail),
        ),
      ],
    );
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => screen),
        GoRoute(path: '/catalogs', builder: (_, _) => screen),
        GoRoute(
          path: '/other',
          builder: (_, _) => const Scaffold(body: Text('Other screen')),
        ),
        GoRoute(
          path: '/viewer/:id',
          builder: (_, state) {
            final args = state.extra! as ViewerRouteArgs;
            opened.add(args);
            return Scaffold(body: Text('viewer:${args.initialItem!.id}'));
          },
        ),
      ],
    );
  }

  final repository = _MockMediaRepository();
  final MediaItem item;
  final ValueNotifier<MediaCollection> collection;
  MediaCollection freshCatalog;
  final items = <int, MediaItem>{};
  final itemReads = <int>[];
  final opened = <ViewerRouteArgs>[];
  late Future<Result<MediaItem?, AppError>> Function(int) readItem;
  late final ProviderContainer container;
  late final GoRouter router;

  Widget get screen => Scaffold(
    appBar: AppBar(title: const Text('旅行の記録')),
    body: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('カタログの情報')),
          ValueListenableBuilder<MediaCollection>(
            valueListenable: collection,
            builder: (_, value, _) => ResumeBanner(collection: value),
          ),
          for (var i = 0; i < 16; i++)
            ListTile(title: Text('Library file $i.pdf')),
        ],
      ),
    ),
  );

  Widget app({
    Locale locale = const Locale('ja'),
    double scale = 1,
    bool dark = false,
    bool withRouter = true,
  }) {
    var theme = dark ? AppTheme.dark : AppTheme.light;
    if (_previewFont.isNotEmpty) {
      ButtonStyle previewStyle(ButtonStyle? original) {
        final style = original ?? const ButtonStyle();
        final text = style.textStyle?.resolve({}) ?? const TextStyle();
        return style.copyWith(
          textStyle: WidgetStatePropertyAll(
            text.copyWith(fontFamily: 'ResumePreview'),
          ),
        );
      }

      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'ResumePreview'),
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
            fontFamily: 'ResumePreview',
          ),
        ),
        listTileTheme: theme.listTileTheme.copyWith(
          titleTextStyle: theme.listTileTheme.titleTextStyle?.copyWith(
            fontFamily: 'ResumePreview',
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: previewStyle(theme.filledButtonTheme.style),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: previewStyle(theme.outlinedButtonTheme.style),
        ),
        textButtonTheme: TextButtonThemeData(
          style: previewStyle(theme.textButtonTheme.style),
        ),
      );
    }
    Widget builder(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: RepaintBoundary(key: _previewBoundary, child: child!),
    );

    return UncontrolledProviderScope(
      container: container,
      child: withRouter
          ? MaterialApp.router(
              routerConfig: router,
              theme: theme,
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: builder,
            )
          : MaterialApp(
              home: screen,
              theme: theme,
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: builder,
            ),
    );
  }

  void dispose() {
    router.dispose();
    container.dispose();
    collection.dispose();
  }
}

_Harness _harness({
  String fileName = _jaName,
  DateTime? viewedAt,
  bool secretThumbnail = false,
}) {
  final harness = _Harness(
    fileName: fileName,
    viewedAt: viewedAt,
    secretThumbnail: secretThumbnail,
  );
  addTearDown(harness.dispose);
  return harness;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ResumeBanner)))!;

Future<void> _capture(WidgetTester tester, String name) async {
  if (_previewFont.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewBoundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/ux_review');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/catalog-resume-$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void _expectFullName(WidgetTester tester, String name) {
  final finder = find.byKey(_name);
  final widget = tester.widget<Text>(finder);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(widget.data, name);
  expect(widget.maxLines, isNull);
  expect(paragraph.didExceedMaxLines, isFalse);
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    textAlign: paragraph.textAlign,
    locale: paragraph.locale,
    strutStyle: paragraph.strutStyle,
    textWidthBasis: paragraph.textWidthBasis,
    textHeightBehavior: paragraph.textHeightBehavior,
  )..layout(maxWidth: paragraph.size.width);
  try {
    expect(paragraph.size.height, closeTo(painter.height, 0.01));
    final lines = painter.computeLineMetrics();
    expect(lines, isNotEmpty);
    expect(lines.last.width, lessThanOrEqualTo(paragraph.size.width + 0.01));
    final ending = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: name.length - 5, extentOffset: name.length),
    );
    expect(ending, isNotEmpty);
    for (final box in ending) {
      expect(box.right, lessThanOrEqualTo(paragraph.size.width + 0.01));
      expect(box.bottom, lessThanOrEqualTo(paragraph.size.height + 0.01));
    }
  } finally {
    painter.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    registerFallbackValue(const MediaFilter());
    for (final font in [
      ('ResumePreview', _previewFont),
      ('MaterialIcons', _previewIcons),
    ]) {
      if (font.$2.isEmpty) continue;
      final loader = FontLoader(font.$1);
      loader.addFont(File(font.$2).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final state in ['no history', 'ordinary folder', 'unavailable']) {
    testWidgets('$state has no resume control or unavailable notification', (
      tester,
    ) async {
      final h = _harness();
      if (state == 'no history') {
        h.collection.value.lastViewedItemId = null;
      } else if (state == 'ordinary folder') {
        h.collection.value.isCatalog = false;
      } else {
        h.readItem = (_) async => Result.success(null);
      }
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      expect(find.byKey(_panel), findsNothing);
      expect(find.byKey(_open), findsNothing);
      expect(find.text(_l10n(tester).resumeBannerUnavailable), findsNothing);
      expect(h.opened, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'uses a fresh viewed date and full filename, then opens that file',
    (tester) async {
      final viewedAt = DateTime(2024, 7, 18, 13, 45);
      final h = _harness(viewedAt: viewedAt);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(ResumeBanner));
      final l10n = _l10n(tester);
      final date = DateTimeUtils.formatDateTime(context, viewedAt.toLocal());
      expect(find.text(l10n.resumeBannerLastOpenedFile), findsOneWidget);
      expect(find.text(l10n.resumeBannerLastViewedAt(date)), findsOneWidget);
      expect(find.textContaining('2000'), findsNothing);
      expect(find.textContaining('2001'), findsNothing);
      _expectFullName(tester, _jaName);
      await tester.tap(find.byKey(_open));
      await tester.pumpAndSettle();
      expect(find.text('viewer:3'), findsOneWidget);
      expect(h.opened.single.initialItem, same(h.item));
      expect(h.opened.single.sourceContext!.parentPath, h.item.parentPath);
      expect(h.opened.single.sourceContext!.kind, ViewerSourceKind.folder);
      expect(h.opened.single.sourceContext!.appMode, AppMode.internal);
      expect(h.itemReads, [3, 3]);
      h.router.pop();
      await tester.pumpAndSettle();
      expect(find.text(_jaName), findsOneWidget);
      expect(find.byKey(_open).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a null last-viewed date is omitted rather than using updatedAt',
    (tester) async {
      final h = _harness();
      await tester.pumpWidget(h.app(locale: const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.byKey(_name), findsOneWidget);
      expect(find.textContaining('Last viewed:'), findsNothing);
      expect(find.textContaining('2000'), findsNothing);
      expect(find.textContaining('2001'), findsNothing);
    },
  );

  testWidgets('pending initial reads reveal no filename or content preview', (
    tester,
  ) async {
    final h = _harness();
    final pending = Completer<Result<MediaItem?, AppError>>();
    h.readItem = (_) => pending.future;
    await tester.pumpWidget(h.app());
    await tester.pump();
    expect(find.byKey(_checking), findsOneWidget);
    expect(find.byKey(_name), findsNothing);
    expect(find.byType(Image), findsNothing);
    pending.complete(Result.success(h.item));
    await tester.pumpAndSettle();
    expect(find.text(_jaName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an initial read failure explains and retries only the read', (
    tester,
  ) async {
    final h = _harness();
    h.readItem = (_) async => Result.failure(AppError.database('read failure'));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text(_l10n(tester).resumeBannerReadFailed), findsOneWidget);
    expect(find.byKey(_name), findsNothing);
    expect(find.byKey(_reload), findsOneWidget);
    h.readItem = (id) async => Result.success(h.items[id]);
    await tester.tap(find.byKey(_reload));
    await tester.pumpAndSettle();
    expect(find.text(_jaName), findsOneWidget);
    expect(h.opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an activation read failure recovers without opening on reload', (
    tester,
  ) async {
    final h = _harness();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    h.readItem = (_) async => Result.failure(AppError.database('read failure'));
    await tester.tap(find.byKey(_open));
    await tester.pumpAndSettle();
    expect(find.text(_l10n(tester).resumeBannerReadFailed), findsOneWidget);
    expect(find.text(_jaName), findsNothing);
    expect(find.byKey(_reload), findsOneWidget);
    h.readItem = (id) async => Result.success(h.items[id]);
    await tester.tap(find.byKey(_reload));
    await tester.pumpAndSettle();
    expect(find.text(_jaName), findsOneWidget);
    expect(h.opened, isEmpty);
    await tester.tap(find.byKey(_open));
    await tester.pumpAndSettle();
    expect(find.text('viewer:3'), findsOneWidget);
    h.router.pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an unavailable activation explains once and hides the old target',
    (tester) async {
      final h = _harness();
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      final unavailable = _l10n(tester).resumeBannerUnavailable;
      h.readItem = (_) async => Result.success(null);
      await tester.tap(find.byKey(_open));
      await tester.pumpAndSettle();
      expect(find.text(unavailable), findsOneWidget);
      expect(find.text(_jaName), findsNothing);
      expect(find.byKey(_panel), findsNothing);
      expect(h.opened, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'navigation failure has a separate explanation and same-open retry',
    (tester) async {
      final h = _harness();
      await tester.pumpWidget(h.app(withRouter: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_open));
      await tester.pumpAndSettle();
      final l10n = _l10n(tester);
      expect(find.text(l10n.resumeBannerOpenFailed), findsOneWidget);
      expect(find.text(l10n.resumeBannerReadFailed), findsNothing);
      expect(find.byKey(_reload), findsNothing);
      expect(find.text(l10n.commonRetry), findsOneWidget);
      final reads = h.itemReads.length;
      await tester.tap(find.byKey(_open));
      await tester.pumpAndSettle();
      expect(h.itemReads.length, reads + 1);
      expect(find.text(l10n.resumeBannerOpenFailed), findsOneWidget);
      expect(h.opened, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rapid activation checks once and hides the old target while pending',
    (tester) async {
      final h = _harness();
      h.item.thumbnailPath = File(
        'assets/images/samples/illustration_collection/starlight_observatory.png',
      ).absolute.path;
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      final pending = Completer<Result<MediaItem?, AppError>>();
      h.readItem = (_) => pending.future;
      final reads = h.itemReads.length;
      await tester.tap(find.byKey(_open));
      await tester.tap(find.byKey(_open));
      await tester.pump();
      expect(h.itemReads.length, reads + 1);
      expect(find.byKey(_checking), findsOneWidget);
      expect(find.byKey(_name), findsNothing);
      expect(find.byType(Image), findsNothing);
      pending.complete(Result.success(h.item));
      await tester.pumpAndSettle();
      expect(find.text('viewer:3'), findsOneWidget);
      expect(h.opened, hasLength(1));
      h.router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(_checking), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final cancellation in [
    'tab round trip',
    'mode round trip',
    'secret round trip',
    'target change',
    'route pop',
    'route cover',
    'route round trip',
    'unmount',
  ]) {
    testWidgets(
      'a pending activation respects $cancellation and ignores its result',
      (tester) async {
        final h = _harness();
        await tester.pumpWidget(h.app());
        await tester.pumpAndSettle();
        if (cancellation == 'route pop') {
          unawaited(h.router.push<void>('/catalogs'));
          await tester.pumpAndSettle();
        }
        final pending = Completer<Result<MediaItem?, AppError>>();
        var delayed = false;
        h.readItem = (id) {
          if (!delayed) {
            delayed = true;
            return pending.future;
          }
          return Future.value(Result.success(h.items[id]));
        };
        await tester.tap(find.byKey(_open));
        await tester.pump();
        expect(find.byKey(_checking), findsOneWidget);
        if (cancellation == 'tab round trip') {
          h.container.read(currentTabIndexProvider.notifier).goToHome();
          h.container.read(currentTabIndexProvider.notifier).goToLibrary();
        } else if (cancellation == 'mode round trip') {
          h.container.read(_mode.notifier).state = AppMode.external;
          h.container.read(appModeProvider);
          h.container.read(_mode.notifier).state = AppMode.internal;
          h.container.read(appModeProvider);
        } else if (cancellation == 'secret round trip') {
          final secret =
              h.container.read(secretModeProvider.notifier) as _Secret;
          secret.set(true);
          secret.set(false);
        } else if (cancellation == 'target change') {
          final next = _file(id: 4, name: 'Different-ending-B.pdf');
          h.items[next.id] = next;
          h.freshCatalog = _catalog(itemId: next.id);
          h.collection.value = _catalog(itemId: next.id);
        } else if (cancellation == 'route pop') {
          h.router.pop();
        } else if (cancellation.startsWith('route ')) {
          unawaited(h.router.push<void>('/other'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          if (cancellation == 'route round trip') {
            h.router.pop();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          }
        } else {
          await tester.pumpWidget(const SizedBox.shrink());
        }
        await tester.pump();
        pending.complete(Result.success(h.item));
        await tester.pumpAndSettle();
        expect(find.text('viewer:3'), findsNothing);
        expect(h.opened, isEmpty);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byKey(_checking), findsNothing);
        if (cancellation == 'target change') {
          expect(find.text(_jaName), findsNothing);
          expect(find.text('Different-ending-B.pdf'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final result in ['unavailable', 'failure']) {
    testWidgets(
      'a cancelled activation silently ignores a late $result result',
      (tester) async {
        final h = _harness();
        await tester.pumpWidget(h.app());
        await tester.pumpAndSettle();
        final pending = Completer<Result<MediaItem?, AppError>>();
        h.readItem = (_) => pending.future;
        await tester.tap(find.byKey(_open));
        await tester.pump();
        h.container.read(currentTabIndexProvider.notifier).goToHome();
        h.container.read(currentTabIndexProvider.notifier).goToLibrary();
        await tester.pump();
        pending.complete(
          result == 'failure'
              ? Result.failure(AppError.database('late failure'))
              : Result.success(null),
        );
        await tester.pumpAndSettle();
        expect(h.opened, isEmpty);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byKey(_reload), findsNothing);
        expect(find.text(_jaName), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'secret visibility admits a hidden target without exposing a thumbnail',
    (tester) async {
      final h = _harness(secretThumbnail: true);
      h.item.thumbnailPath = File(
        'assets/images/samples/illustration_collection/starlight_observatory.png',
      ).absolute.path;
      h.item.isHidden = true;
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      expect(find.byKey(_panel), findsNothing);
      (h.container.read(secretModeProvider.notifier) as _Secret).set(true);
      await tester.pumpAndSettle();
      expect(find.text(_jaName), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in ['ja', 'en']) {
    for (final dark in [false, true]) {
      testWidgets(
        '320dp 200% preserves full $locale name and list access dark=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final fileName = locale == 'ja' ? _jaName : _enName;
          final h = _harness(
            fileName: fileName,
            viewedAt: DateTime(2024, 7, 18, 13, 45),
          );
          await tester.pumpWidget(
            h.app(locale: Locale(locale), scale: 2, dark: dark),
          );
          await tester.pumpAndSettle();
          _expectFullName(tester, fileName);
          final panel = tester.getRect(
            find
                .descendant(
                  of: find.byKey(_panel),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(panel.left, greaterThanOrEqualTo(16));
          expect(panel.right, lessThanOrEqualTo(304));
          final button = tester.getRect(find.byKey(_open));
          final filename = tester.getRect(find.byKey(_name));
          expect(button.width, greaterThanOrEqualTo(48));
          expect(button.height, greaterThanOrEqualTo(48));
          expect(button.top, greaterThanOrEqualTo(filename.bottom));
          if (locale == 'ja' && !dark) {
            await _capture(tester, 'ja-320-200');
          }
          await tester.ensureVisible(find.byKey(_open));
          expect(find.byKey(_open).hitTestable(), findsOneWidget);
          if (locale == 'ja' && !dark) {
            await tester.pump();
            await _capture(tester, 'ja-320-200-action');
          }
          await tester.ensureVisible(find.text('Library file 15.pdf'));
          expect(
            find.text('Library file 15.pdf').hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final locale in ['ja', 'en']) {
    testWidgets('a standard $locale banner has one accessible activation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        final fileName = locale == 'ja' ? _jaName : _enName;
        final h = _harness(
          fileName: fileName,
          viewedAt: DateTime(2024, 7, 18, 13, 45),
        );
        await tester.pumpWidget(h.app(locale: Locale(locale)));
        await tester.pumpAndSettle();
        _expectFullName(tester, fileName);
        final data = tester.getSemantics(find.byKey(_open)).getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
        final label = data.attributedLabel.string;
        expect(label.split(fileName), hasLength(2));
        expect(label, contains(_l10n(tester).resumeBannerLastOpenedFile));
        expect(label, contains(_l10n(tester).resumeBannerAction));
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(fileName))),
          findsOneWidget,
        );
        expect(
          tester.semantics.simulatedAccessibilityTraversal().where((node) {
            final data = node.getSemanticsData();
            return data.hasAction(ui.SemanticsAction.tap) &&
                data.attributedLabel.string.contains(
                  _l10n(tester).resumeBannerAction,
                );
          }),
          hasLength(1),
        );
        final button = tester.getSize(find.byKey(_open));
        expect(button.width, greaterThanOrEqualTo(48));
        expect(button.height, greaterThanOrEqualTo(48));
        await _capture(tester, '$locale-390-100');
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}
