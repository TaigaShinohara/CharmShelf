import 'dart:async';
import 'package:private_shelf/core/providers/tab_navigation_provider.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/presentation/providers/collection_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_list_view.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/catalog_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockMediaRepository extends Mock implements MediaRepository {}

class _Collection extends CollectionNotifier {
  _Collection(this.collection);

  final MediaCollection collection;

  @override
  Future<MediaCollection?> build(String path) async => collection;
}

class _Filter extends MediaFilterNotifier {
  @override
  MediaFilter build(AppMode mode) => const MediaFilter(
    rootOnly: true,
    sourceType: MediaSourceType.localCopy,
    sortOrder: SortOrder.nameAsc,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const MediaFilter());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final outcome in ['open', 'unmount', 'back', 'tab']) {
    final cancel = outcome != 'open';
    testWidgets('カタログ取得中は即時反応し重複遷移せず、離脱を尊重する outcome=$outcome', (tester) async {
      final repository = _MockMediaRepository();
      final collection = MediaCollection()
        ..path = 'catalog'
        ..title = '旅行'
        ..isCatalog = true
        ..type = CollectionType.folder
        ..lastViewedItemId = 3;
      final folder = MediaItem()
        ..id = 1
        ..path = collection.path
        ..type = MediaType.folder
        ..sourceType = MediaSourceType.localCopy;
      folder.collection.value = collection;
      final resumed = MediaItem()
        ..id = 3
        ..path = 'catalog/b.jpg'
        ..parentPath = collection.path
        ..type = MediaType.file
        ..sourceType = MediaSourceType.localCopy;

      when(
        () => repository.getById(3),
      ).thenAnswer((_) async => Result.success(resumed));
      final pending = Completer<Result<List<MediaItem>, AppError>>();
      when(
        () => repository.getAll(filter: any(named: 'filter')),
      ).thenAnswer((_) => pending.future);

      late final GoRouter router;
      router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: MediaListView(items: [folder])),
          ),
          GoRoute(
            path: '/catalogs',
            builder: (_, _) => Scaffold(body: MediaListView(items: [folder])),
          ),
          GoRoute(
            path: '/viewer/:id',
            builder: (_, state) {
              final args = state.extra! as ViewerRouteArgs;
              return Scaffold(
                body: Text(
                  'viewer:${args.initialItem!.id}:${args.sourceContext!.customItems!.length}',
                ),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hapticsEnabledProvider.overrideWith((ref) => false),
            globalSimpleDisplayProvider.overrideWith((ref) => true),
            mediaRepositoryProvider.overrideWith((ref) async => repository),
            mediaFilterNotifierProvider(
              AppMode.internal,
            ).overrideWith(() => _Filter()),
            collectionNotifierProvider(
              collection.path,
            ).overrideWith(() => _Collection(collection)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('ja'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ja'), Locale('en')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (outcome == 'back') {
        unawaited(router.push<void>('/catalogs'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byType(CatalogTile));
      await tester.pump();
      expect(find.byKey(const ValueKey('catalog-opening')), findsOneWidget);
      await tester.tap(find.byType(CatalogTile));
      await tester.pump();
      verify(() => repository.getAll(filter: any(named: 'filter'))).called(1);
      if (outcome == 'unmount') {
        await tester.pumpWidget(const SizedBox.shrink());
      } else if (outcome == 'tab') {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(CatalogTile)),
        );
        container.read(currentTabIndexProvider.notifier).goToHome();
        container.read(currentTabIndexProvider.notifier).goToLibrary();
        await tester.pump();
        expect(find.byKey(const ValueKey('catalog-opening')), findsNothing);
      } else if (outcome == 'back') {
        router.pop();
        await tester.pump();
        expect(find.byKey(const ValueKey('catalog-opening')), findsNothing);
      }
      pending.complete(Result.success([resumed]));
      await tester.pumpAndSettle();
      expect(find.text('viewer:3:1'), cancel ? findsNothing : findsOneWidget);
      expect(find.byKey(const ValueKey('catalog-opening')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
