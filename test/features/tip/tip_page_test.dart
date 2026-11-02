import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/tip/data/tip_purchase_service.dart';
import 'package:private_shelf/features/tip/domain/tip_item.dart';
import 'package:private_shelf/features/tip/presentation/providers/tip_purchase_provider.dart';
import 'package:private_shelf/features/tip/presentation/tip_page.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class _FakeTipPurchaseService implements TipPurchaseService {
  _FakeTipPurchaseService({required this.catalog});

  final TipCatalog catalog;
  @override
  TipItem? pendingItem;

  int recoveryCount = 0;

  @override
  Future<void> recoverPendingPurchases() async {
    recoveryCount++;
  }

  final purchasedItems = <TipItem>[];
  Future<bool> Function(TipItem)? onPurchase;
  final _updates = StreamController<TipPurchaseUpdate>.broadcast();
  TipPurchaseUpdate? _latestUpdate;

  @override
  Stream<TipPurchaseUpdate> get updates => _updates.stream;

  @override
  TipPurchaseUpdate? get latestUpdate => _latestUpdate;

  @override
  Future<TipCatalog> loadCatalog() async => catalog;

  @override
  Future<bool> purchase(TipItem item) async {
    purchasedItems.add(item);
    return onPurchase?.call(item) ?? true;
  }

  void emit(TipPurchaseUpdate update) {
    _latestUpdate = update;
    _updates.add(update);
  }

  @override
  void dispose() => _updates.close();
}

void main() {
  for (final language in ['ja', 'en']) {
    testWidgets('$language: 320px・文字200%でも価格未取得を表示できる', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _FakeTipPurchaseService(
        catalog: const TipCatalog(isStoreAvailable: false, prices: {}),
      );
      await tester.pumpWidget(
        _testApp(service, language: language, textScale: 2),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets('$language: 画面を開く前の未確認取引も履歴確認案内を表示する', (tester) async {
      final service = _FakeTipPurchaseService(
        catalog: const TipCatalog(
          isStoreAvailable: true,
          prices: {
            TipItem.juice: '¥160',
            TipItem.coffee: '¥480',
            TipItem.ramen: '¥1,440',
          },
        ),
      );
      service.emit(
        const TipPurchaseUpdate(
          item: TipItem.juice,
          type: TipPurchaseUpdateType.unconfirmed,
        ),
      );
      await tester.pumpWidget(_testApp(service, language: language));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(TipPage)))!;
      expect(find.text(l10n.tipPurchaseUnconfirmed), findsOneWidget);
      expect(find.text(l10n.tipPurchaseThankYou), findsNothing);
      expect(find.text(l10n.tipPurchaseCanceled), findsNothing);
      expect(find.text(l10n.tipPurchaseFailed), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(service.purchasedItems, isEmpty);
      expect(service.recoveryCount, 0);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '¥160'))
            .onPressed,
        isNotNull,
      );
    });
  }
  testWidgets('完了失敗時は未完了取引を表示して再試行できる', (tester) async {
    final service = _FakeTipPurchaseService(
      catalog: const TipCatalog(
        isStoreAvailable: true,
        prices: {
          TipItem.juice: '¥160',
          TipItem.coffee: '¥480',
          TipItem.ramen: '¥1,440',
        },
      ),
    );
    await tester.pumpWidget(_testApp(service));
    await tester.pumpAndSettle();
    service.pendingItem = TipItem.juice;
    service.emit(
      const TipPurchaseUpdate(
        item: TipItem.juice,
        type: TipPurchaseUpdateType.failed,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final retry = find.widgetWithText(OutlinedButton, '再試行');
    expect(retry, findsOneWidget);
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    expect(service.recoveryCount, 1);
  });

  test('画面の購読終了後も完了通知を保持する', () async {
    final service = _FakeTipPurchaseService(
      catalog: const TipCatalog(
        isStoreAvailable: true,
        prices: {TipItem.juice: '¥160'},
      ),
    );
    final container = ProviderContainer(
      overrides: [tipPurchaseServiceProvider.overrideWithValue(service)],
    );
    addTearDown(() {
      container.dispose();
      service.dispose();
    });
    final subscription = container.listen(tipPurchaseProvider, (_, _) {});
    await container.read(tipPurchaseProvider.future);
    subscription.close();
    await Future<void>.delayed(Duration.zero);
    service.emit(
      const TipPurchaseUpdate(
        item: TipItem.juice,
        type: TipPurchaseUpdateType.completed,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final state = await container.read(tipPurchaseProvider.future);
    expect(state.completedItem, TipItem.juice);
    expect(state.pendingItem, isNull);
  });

  test('前の成功を未確認・失敗・取消・新規購入の状態へ持ち越さない', () async {
    final service = _FakeTipPurchaseService(
      catalog: const TipCatalog(
        isStoreAvailable: true,
        prices: {TipItem.juice: '¥160', TipItem.coffee: '¥480'},
      ),
    );
    final container = ProviderContainer(
      overrides: [tipPurchaseServiceProvider.overrideWithValue(service)],
    );
    addTearDown(() {
      container.dispose();
      service.dispose();
    });
    await container.read(tipPurchaseProvider.future);
    for (final type in [
      TipPurchaseUpdateType.unconfirmed,
      TipPurchaseUpdateType.failed,
      TipPurchaseUpdateType.canceled,
    ]) {
      service.emit(
        const TipPurchaseUpdate(
          item: TipItem.juice,
          type: TipPurchaseUpdateType.completed,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        (await container.read(tipPurchaseProvider.future)).completedItem,
        TipItem.juice,
      );
      service.emit(TipPurchaseUpdate(item: TipItem.coffee, type: type));
      await Future<void>.delayed(Duration.zero);
      final state = await container.read(tipPurchaseProvider.future);
      expect(state.event, type);
      expect(state.completedItem, isNull);
    }
    service.emit(
      const TipPurchaseUpdate(
        item: TipItem.juice,
        type: TipPurchaseUpdateType.completed,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await container.read(tipPurchaseProvider.notifier).purchase(TipItem.coffee);
    final state = await container.read(tipPurchaseProvider.future);
    expect(state.event, TipPurchaseUpdateType.pending);
    expect(state.completedItem, isNull);
  });

  test('再構築では購読の隙間に保持された最新の未確認通知を読む', () async {
    final service = _FakeTipPurchaseService(
      catalog: const TipCatalog(
        isStoreAvailable: true,
        prices: {TipItem.juice: '¥160'},
      ),
    );
    final container = ProviderContainer(
      overrides: [tipPurchaseServiceProvider.overrideWithValue(service)],
    );
    addTearDown(() {
      container.dispose();
      service.dispose();
    });
    await container.read(tipPurchaseProvider.future);
    service.pendingItem = TipItem.juice;
    service.emit(
      const TipPurchaseUpdate(
        item: TipItem.juice,
        type: TipPurchaseUpdateType.pending,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    service.pendingItem = null;
    // The service retains a notification even if the broadcast was not observed.
    service._latestUpdate = const TipPurchaseUpdate(
      item: TipItem.juice,
      type: TipPurchaseUpdateType.unconfirmed,
    );
    container.read(tipPurchaseProvider.notifier).retry();
    final state = await container.read(tipPurchaseProvider.future);
    expect(state.event, TipPurchaseUpdateType.unconfirmed);
    expect(state.pendingItem, isNull);
    expect(state.completedItem, isNull);
  });

  test('古い購入開始失敗は未確認通知や次の購入中状態を上書きしない', () async {
    final service = _FakeTipPurchaseService(
      catalog: const TipCatalog(
        isStoreAvailable: true,
        prices: {TipItem.juice: '¥160', TipItem.coffee: '¥480'},
      ),
    );
    final container = ProviderContainer(
      overrides: [tipPurchaseServiceProvider.overrideWithValue(service)],
    );
    addTearDown(() {
      container.dispose();
      service.dispose();
    });
    await container.read(tipPurchaseProvider.future);
    final first = Completer<bool>();
    final second = Completer<bool>();
    service.onPurchase = (item) {
      service.pendingItem = item;
      service.emit(
        TipPurchaseUpdate(item: item, type: TipPurchaseUpdateType.pending),
      );
      return item == TipItem.juice ? first.future : second.future;
    };
    final notifier = container.read(tipPurchaseProvider.notifier);
    final firstPurchase = notifier.purchase(TipItem.juice);
    await Future<void>.delayed(Duration.zero);
    service.pendingItem = null;
    service.emit(
      const TipPurchaseUpdate(
        item: TipItem.juice,
        type: TipPurchaseUpdateType.unconfirmed,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      (await container.read(tipPurchaseProvider.future)).event,
      TipPurchaseUpdateType.unconfirmed,
    );
    final secondPurchase = notifier.purchase(TipItem.coffee);
    await Future<void>.delayed(Duration.zero);
    first.complete(false);
    await firstPurchase;
    var state = await container.read(tipPurchaseProvider.future);
    expect(state.pendingItem, TipItem.coffee);
    expect(state.event, TipPurchaseUpdateType.pending);
    expect(state.completedItem, isNull);
    second.complete(true);
    await secondPurchase;
    state = await container.read(tipPurchaseProvider.future);
    expect(state.pendingItem, TipItem.coffee);
    expect(state.event, TipPurchaseUpdateType.pending);
  });

  test('購入開始の返答前の未確認通知を開始失敗に置き換えない', () async {
    final service = _FakeTipPurchaseService(
      catalog: const TipCatalog(
        isStoreAvailable: true,
        prices: {TipItem.juice: '¥160'},
      ),
    );
    final container = ProviderContainer(
      overrides: [tipPurchaseServiceProvider.overrideWithValue(service)],
    );
    addTearDown(() {
      container.dispose();
      service.dispose();
    });
    await container.read(tipPurchaseProvider.future);
    final response = Completer<bool>();
    service.onPurchase = (_) => response.future;
    final purchasing = container
        .read(tipPurchaseProvider.notifier)
        .purchase(TipItem.juice);
    service.emit(
      const TipPurchaseUpdate(
        item: TipItem.juice,
        type: TipPurchaseUpdateType.unconfirmed,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    response.complete(false);
    await purchasing;
    final state = await container.read(tipPurchaseProvider.future);
    expect(state.pendingItem, isNull);
    expect(state.event, TipPurchaseUpdateType.unconfirmed);
    expect(state.completedItem, isNull);
  });

  testWidgets('チップ商品を表示し、確認後にだけ購入を開始する', (tester) async {
    final service = _FakeTipPurchaseService(
      catalog: const TipCatalog(
        isStoreAvailable: true,
        prices: {
          TipItem.juice: r'$1.00',
          TipItem.coffee: r'$3.00',
          TipItem.ramen: r'$9.00',
        },
      ),
    );

    await tester.pumpWidget(_testApp(service));
    await tester.pumpAndSettle();

    expect(find.text('ジュース一杯'), findsOneWidget);
    expect(find.text('コーヒー一杯'), findsOneWidget);
    expect(find.text('ラーメン一杯'), findsOneWidget);
    expect(find.text(r'$1.00'), findsOneWidget);
    expect(find.text(r'$3.00'), findsOneWidget);
    expect(find.text(r'$9.00'), findsOneWidget);

    await tester.tap(find.text(r'$1.00'));
    await tester.pumpAndSettle();

    expect(service.purchasedItems, isEmpty);
    expect(find.text(r'ジュース一杯（$1.00）を購入しますか？'), findsOneWidget);

    await tester.tap(find.text('購入へ進む'));
    await tester.pump();

    expect(service.purchasedItems, [TipItem.juice]);

    service.emit(
      const TipPurchaseUpdate(
        item: TipItem.juice,
        type: TipPurchaseUpdateType.completed,
      ),
    );
    await tester.pump();

    expect(find.text('応援ありがとうございます！'), findsOneWidget);
  });

  testWidgets('ストア商品が未取得のときは購入できない', (tester) async {
    final service = _FakeTipPurchaseService(
      catalog: const TipCatalog(isStoreAvailable: false, prices: {}),
    );

    await tester.pumpWidget(_testApp(service));
    await tester.pumpAndSettle();

    expect(find.text('ストアの商品情報を取得できません。時間をおいてお試しください。'), findsOneWidget);
    expect(service.purchasedItems, isEmpty);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '価格を取得できません').first,
          )
          .onPressed,
      isNull,
    );
  });
}

Widget _testApp(
  _FakeTipPurchaseService service, {
  String language = 'ja',
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [tipPurchaseServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      locale: Locale(language),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja'), Locale('en')],
      home: const TipPage(),
    ),
  );
}
