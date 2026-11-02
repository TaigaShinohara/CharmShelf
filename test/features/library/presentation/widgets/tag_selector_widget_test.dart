import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/application/use_cases/tag_use_cases.dart';
import 'package:private_shelf/features/library/data/repositories/tag_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/repositories/tag_repository.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_facet_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/tag_view_model.dart';
import 'package:private_shelf/features/library/presentation/widgets/tag_selector_widget.dart';
import 'package:private_shelf/features/library/presentation/widgets/tag_form_sheet.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/tag/app_tag.dart';
import 'package:private_shelf/shared/widgets/sheets/app_bottom_sheet.dart';
import 'package:private_shelf/shared/widgets/sheets/sheet_handle.dart';

class _TagRepository extends Mock implements TagRepository {}

class _SyncTags extends Mock implements SyncCollectionTagsUseCase {}

class _Tags extends TagListViewModel {
  final tags = <Tag>[];
  int createCount = 0;
  bool failCreation = false;
  Completer<void>? createGate;
  int? lastFacetId;

  @override
  Stream<List<Tag>> build() => Stream.value([...tags]);

  @override
  Future<Tag> addTag(
    String name, {
    int? facetId,
    int? parentId,
    int? level,
    int? colorValue,
    bool isHidden = false,
  }) async {
    createCount++;
    lastFacetId = facetId;
    await createGate?.future;
    if (failCreation) throw AppError.validation('Save failed');
    final tag = Tag()
      ..id = tags.length + 1
      ..name = name
      ..facetId = facetId;
    tags.add(tag);
    state = AsyncData([...tags]);
    return tag;
  }
}

class _Facets extends TagFacetListViewModel {
  @override
  Stream<List<TagFacet>> build() => Stream.value([
    TagFacet()
      ..id = 7
      ..name = '旅行',
  ]);
}

void main() {
  late _Tags tags;
  late _TagRepository repository;
  late _SyncTags sync;
  late MediaItem item;

  setUpAll(() {
    registerFallbackValue(MediaItem());
    registerFallbackValue(<Tag>[]);
  });

  setUp(() {
    tags = _Tags();
    repository = _TagRepository();
    sync = _SyncTags();
    item = MediaItem()..path = 'photo.png';
    item.collection.value = MediaCollection()..path = 'photo.png';
    when(
      () => repository.getAll(),
    ).thenAnswer((_) async => Result.success([...tags.tags]));
    when(
      () => sync.invoke(any(), any()),
    ).thenAnswer((_) async => Result.success(null));
  });

  Future<void> openSelector(
    WidgetTester tester, {
    Locale locale = const Locale('ja'),
    double textScale = 1,
    bool inSheet = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagListViewModelProvider.overrideWith(() => tags),
          visibleTagListProvider.overrideWith(
            (ref) => ref.watch(tagListViewModelProvider),
          ),
          tagFacetListViewModelProvider.overrideWith(() => _Facets()),
          tagRepositoryProvider.overrideWith((ref) async => repository),
          syncCollectionTagsUseCaseProvider.overrideWith((ref) => sync),
        ],
        child: MaterialApp(
          locale: locale,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: inSheet
                ? Builder(
                    builder: (context) => TextButton(
                      onPressed: () {
                        final saving = ValueNotifier(false);
                        showAppBottomSheet(
                          context,
                          title: AppLocalizations.of(context)!.tagListTitle,
                          useSingleChildScrollView: false,
                          dismissBlocked: saving,
                          child: TagSelectorWidget(
                            item: item,
                            saveInProgress: saving,
                          ),
                        ).whenComplete(saving.dispose);
                      },
                      child: const Text('open'),
                    ),
                  )
                : TagSelectorWidget(item: item),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (inSheet) {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(
      find.byKey(const ValueKey('tag-selector-search')),
      query,
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  final createAction = find.byKey(
    const ValueKey('tag-selector-create-and-attach'),
  );

  testWidgets('未登録語から1操作で作成・付与し、保存成功まで選択済みにしない', (tester) async {
    final completion = Completer<Result<void, AppError>>();
    when(() => sync.invoke(any(), any())).thenAnswer((_) => completion.future);
    await openSelector(tester);
    await search(tester, 'Summer2026');
    expect(find.text('「Summer2026」を作成して付ける'), findsOneWidget);

    await tester.tap(createAction);
    await tester.pump();
    expect(tags.createCount, 1);
    expect(tags.tags.single.name, 'Summer2026');
    expect(find.byKey(const ValueKey('tag-selected-section')), findsNothing);
    expect(tester.widget<FilledButton>(createAction).onPressed, isNull);
    await tester.tap(createAction);
    expect(tags.createCount, 1);

    completion.complete(Result.success(null));
    await tester.pumpAndSettle();
    expect(find.text('1個選択中'), findsOneWidget);
    verify(() => sync.invoke(item, [tags.tags.single])).called(1);
  });

  testWidgets('作成失敗は入力を保持して同じ画面から再試行できる', (tester) async {
    tags.failCreation = true;
    await openSelector(tester);
    await search(tester, 'summer2026');
    await tester.tap(createAction);
    await tester.pumpAndSettle();
    expect(tags.tags, isEmpty);
    expect(find.byKey(const ValueKey('tag-selected-section')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('tag-selector-search')))
          .controller!
          .text,
      'summer2026',
    );
    verifyNever(() => sync.invoke(any(), any()));

    tags.failCreation = false;
    await tester.tap(createAction);
    await tester.pumpAndSettle();
    expect(find.text('1個選択中'), findsOneWidget);
  });

  testWidgets('付与失敗では作成済みタグを再利用し、二重作成せず再試行する', (tester) async {
    when(() => sync.invoke(any(), any())).thenAnswer(
      (_) async => Result.failure(AppError.validation('Attach failed')),
    );
    await openSelector(tester);
    await search(tester, 'summer2026');
    await tester.tap(createAction);
    await tester.pumpAndSettle();
    expect(tags.createCount, 1);
    expect(find.text('「summer2026」を付ける（再試行）'), findsOneWidget);
    expect(find.byKey(const ValueKey('tag-selected-section')), findsNothing);

    when(
      () => sync.invoke(any(), any()),
    ).thenAnswer((_) async => Result.success(null));
    await tester.tap(createAction);
    await tester.pumpAndSettle();
    expect(tags.createCount, 1);
    expect(find.text('1個選択中'), findsOneWidget);
    verify(() => sync.invoke(item, [tags.tags.single])).called(2);
  });

  testWidgets('選択分類が0件でも入力語をその分類に作成・付与できる', (tester) async {
    await openSelector(tester);
    await tester.tap(
      find.ancestor(of: find.text('旅行'), matching: find.byType(FacetChip)),
    );
    await tester.pumpAndSettle();
    await search(tester, 'summer2026');
    await tester.tap(createAction);
    await tester.pumpAndSettle();
    expect(tags.lastFacetId, 7);
    expect(find.text('1個選択中'), findsOneWidget);
  });

  testWidgets('タグ0件でも作成でき、フォームで保存したタグは自動で付く', (tester) async {
    await openSelector(tester);
    expect(createAction, findsOneWidget);
    await tester.tap(createAction);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'first-trip');
    await tester.tap(
      find.descendant(
        of: find.byType(TagFormSheet),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(tags.createCount, 1);
    expect(find.text('1個選択中'), findsOneWidget);
  });

  Future<void> tryDismissPendingSheet(WidgetTester tester, Finder sheet) async {
    final l10n = AppLocalizations.of(tester.element(sheet))!;
    final close = find
        .byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == l10n.tooltipClose,
        )
        .last;
    expect(tester.widget<IconButton>(close).onPressed, isNull);
    await tester.tap(close);
    Navigator.of(tester.element(sheet)).pop();
    await tester.pump();
    await tester.tapAt(const Offset(5, 5));
    await tester.binding.handlePopRoute();
    await tester.pump();
    final topBefore = tester.getTopLeft(sheet).dy;
    await tester.dragFrom(
      tester.getCenter(find.byType(SheetHandle).last),
      const Offset(0, 600),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(sheet, findsOneWidget);
    expect(tester.getTopLeft(sheet).dy, closeTo(topBefore, 1));
    expect(tester.takeException(), isNull);
  }

  testWidgets('新規フォームの保存中は閉じる操作と重複作成を防ぎ付与を1回完了する', (tester) async {
    tags.createGate = Completer<void>();
    await openSelector(tester, inSheet: true);
    await tester.tap(createAction);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'slow-trip');
    final form = find.byType(TagFormSheet);
    final save = tester
        .widget<FilledButton>(
          find.descendant(of: form, matching: find.byType(FilledButton)),
        )
        .onPressed!;
    save();
    save();
    await tester.pump();
    expect(tags.createCount, 1);
    await tryDismissPendingSheet(tester, form);
    expect(tags.tags, isEmpty);
    tags.createGate!.complete();
    await tester.pumpAndSettle();
    expect(form, findsNothing);
    expect(tags.createCount, 1);
    expect(find.byKey(const ValueKey('tag-selected-section')), findsOneWidget);
    verify(() => sync.invoke(item, [tags.tags.single])).called(1);
  });

  testWidgets('検索語の直接作成中も閉じる操作を防ぎ作成と付与を1回完了する', (tester) async {
    tags.createGate = Completer<void>();
    final attachGate = Completer<Result<void, AppError>>();
    when(() => sync.invoke(any(), any())).thenAnswer((_) => attachGate.future);
    await openSelector(tester, inSheet: true);
    await search(tester, 'slow-trip');
    await tester.tap(createAction);
    await tester.pump();
    final selector = find.byType(TagSelectorWidget);
    await tryDismissPendingSheet(tester, selector);
    tags.createGate!.complete();
    await tester.pump();
    await tryDismissPendingSheet(tester, selector);
    expect(find.byKey(const ValueKey('tag-selected-section')), findsNothing);
    attachGate.complete(Result.success(null));
    await tester.pumpAndSettle();
    expect(tags.createCount, 1);
    expect(find.byKey(const ValueKey('tag-selected-section')), findsOneWidget);
    verify(() => sync.invoke(item, [tags.tags.single])).called(1);
    final l10n = AppLocalizations.of(tester.element(selector))!;
    await tester.tap(find.byTooltip(l10n.tooltipClose).last);
    await tester.pumpAndSettle();
    expect(selector, findsNothing);
  });

  for (final locale in ['ja', 'en']) {
    testWidgets('$locale: 320dp・200%・キーボード表示中も作成操作に到達できる', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await openSelector(
        tester,
        locale: Locale(locale),
        textScale: 2,
        inSheet: true,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      await search(tester, 'summer2026');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(createAction);
      await tester.pumpAndSettle();
      expect(createAction.hitTestable(), findsOneWidget);
      expect(tester.getBottomLeft(createAction).dy, lessThanOrEqualTo(328));
      expect(tester.getSize(createAction).height, greaterThanOrEqualTo(48));
      await tester.tap(createAction);
      await tester.pumpAndSettle();
      expect(tags.createCount, 1);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('tag-selected-section')),
        findsOneWidget,
      );
    });
  }
}
