import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/features/tip/data/tip_purchase_service.dart';
import 'package:private_shelf/features/tip/domain/tip_item.dart';

class _Store extends Mock implements InAppPurchase {}

class _Android extends Mock implements InAppPurchaseAndroidPlatformAddition {}

class _AndroidPurchase extends Mock implements GooglePlayPurchaseDetails {}

GooglePlayPurchaseDetails androidPurchase(
  String id, {
  String? token,
  TipItem tip = TipItem.juice,
  PurchaseStatus status = PurchaseStatus.purchased,
}) {
  final item = _AndroidPurchase();
  when(() => item.productID).thenReturn(tip.productId);
  when(() => item.purchaseID).thenReturn(id);
  when(() => item.status).thenReturn(status);
  when(() => item.verificationData).thenReturn(
    PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: token ?? 'test-$id',
      source: 'test',
    ),
  );
  return item;
}

PurchaseDetails purchase(
  String id,
  PurchaseStatus status, {
  bool finish = true,
}) {
  return PurchaseDetails(
    purchaseID: id,
    productID: TipItem.juice.productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: 'test-$id',
      source: 'test',
    ),
    transactionDate: '1',
    status: status,
  )..pendingCompletePurchase = finish;
}

SK2PurchaseDetails sk2Purchase(String? id, PurchaseStatus status) {
  // StoreKit 2 sends id:0 without a receipt for pending/cancelled, which its
  // Dart SDK converts to purchaseID:null. Approved purchases have a real ID/JWS.
  return SK2PurchaseDetails(
    purchaseID: id,
    productID: TipItem.juice.productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: id == null ? '' : 'jws-$id',
      source: 'app_store',
    ),
    transactionDate: id == null ? null : '1',
    status: status,
  );
}

Future<void> drain() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Store store;
  late _Android android;
  late StreamController<List<PurchaseDetails>> events;
  late StoreTipPurchaseService service;
  late List<TipPurchaseUpdate> updates;

  setUpAll(() {
    registerFallbackValue(purchase('fallback', PurchaseStatus.purchased));
    registerFallbackValue(
      PurchaseParam(
        productDetails: ProductDetails(
          id: 'tip_juice_1',
          title: 'tip',
          description: 'tip',
          price: '¥100',
          rawPrice: 100,
          currencyCode: 'JPY',
        ),
      ),
    );
  });
  setUp(() {
    store = _Store();
    android = _Android();
    events = StreamController<List<PurchaseDetails>>.broadcast();
    updates = [];
    when(() => store.purchaseStream).thenAnswer((_) => events.stream);
    when(() => store.isAvailable()).thenAnswer((_) async => true);
    when(() => store.completePurchase(any())).thenAnswer((_) async {});
    when(
      () => android.queryPastPurchases(),
    ).thenAnswer((_) async => QueryPurchaseDetailsResponse(pastPurchases: []));
    when(() => android.consumePurchase(any())).thenAnswer(
      (_) async => const BillingResultWrapper(responseCode: BillingResponse.ok),
    );
  });
  tearDown(() async {
    service.dispose();
    await events.close();
    await drain();
  });
  void start({
    bool isAndroid = false,
    Future<List<PurchaseDetails>> Function()? unfinishedIosPurchases,
  }) {
    service = StoreTipPurchaseService(
      store: store,
      isAndroid: isAndroid,
      androidAddition: android,
      unfinishedIosPurchases: unfinishedIosPurchases ?? () async => [],
    );
    service.updates.listen(updates.add);
  }

  test('iOSは起動時の未完了取引を明示的に回収する', () async {
    final item = purchase('recovered-ios', PurchaseStatus.purchased);
    start(unfinishedIosPurchases: () async => [item]);
    await drain();
    verify(() => store.completePurchase(item)).called(1);
    expect(updates.single.type, TipPurchaseUpdateType.completed);
  });

  test('重複イベントを直列化し、同じ取引を一度だけ完了する', () async {
    start();
    final item = purchase('1', PurchaseStatus.purchased);
    events.add([item]);
    events.add([item]);
    await drain();
    verify(() => store.completePurchase(item)).called(1);
    expect(
      updates.where((u) => u.type == TipPurchaseUpdateType.completed),
      hasLength(1),
    );
  });

  test('完了失敗は保持し、再取得時に再試行できる', () async {
    start();
    await service.recoverPendingPurchases();
    final item = purchase('2', PurchaseStatus.purchased);
    var attempts = 0;
    when(() => store.completePurchase(item)).thenAnswer((_) async {
      if (attempts++ == 0) throw StateError('通信失敗');
    });
    events.add([item]);
    await drain();
    expect(service.pendingItem, TipItem.juice);
    expect(updates.last.type, TipPurchaseUpdateType.failed);
    await service.recoverPendingPurchases();
    await drain();
    expect(attempts, 2);
    expect(service.pendingItem, isNull);
    expect(updates.last.type, TipPurchaseUpdateType.completed);
  });

  test('完了中にdisposeしても閉じたstreamへ通知しない', () async {
    start();
    final wait = Completer<void>();
    when(() => store.completePurchase(any())).thenAnswer((_) => wait.future);
    events.add([purchase('3', PurchaseStatus.purchased)]);
    await drain();
    service.dispose();
    wait.complete();
    await drain();
    expect(updates, isEmpty);
  });

  test('pendingは完了せず、取消にfinishが必要なら処理する', () async {
    start();
    events.add([purchase('4', PurchaseStatus.pending, finish: false)]);
    await drain();
    verifyNever(() => store.completePurchase(any()));
    expect(service.pendingItem, TipItem.juice);
    final canceled = purchase('4', PurchaseStatus.canceled);
    events.add([canceled]);
    await drain();
    verify(() => store.completePurchase(canceled)).called(1);
    expect(service.pendingItem, isNull);
    expect(updates.last.type, TipPurchaseUpdateType.canceled);
  });

  for (final status in [PurchaseStatus.purchased, PurchaseStatus.canceled]) {
    test('StoreKit2のIDなしpendingから$statusで購入中状態を解除する', () async {
      final product = ProductDetails(
        id: TipItem.juice.productId,
        title: 'tip',
        description: 'tip',
        price: '¥160',
        rawPrice: 160,
        currencyCode: 'JPY',
      );
      when(() => store.queryProductDetails(any())).thenAnswer(
        (_) async =>
            ProductDetailsResponse(productDetails: [product], notFoundIDs: []),
      );
      when(
        () => store.buyConsumable(purchaseParam: any(named: 'purchaseParam')),
      ).thenAnswer((_) async => true);
      start();
      await service.loadCatalog();
      final pending = sk2Purchase(null, PurchaseStatus.pending);
      expect(pending.purchaseID, isNull);
      expect(pending.pendingCompletePurchase, isFalse);
      events.add([pending]);
      await drain();
      expect(service.pendingItem, TipItem.juice);
      final terminal = sk2Purchase(
        status == PurchaseStatus.purchased ? 'approved-transaction' : null,
        status,
      );
      events.add([terminal]);
      await drain();
      expect(service.pendingItem, isNull);
      expect(
        updates.last.type,
        status == PurchaseStatus.purchased
            ? TipPurchaseUpdateType.completed
            : TipPurchaseUpdateType.canceled,
      );
      if (status == PurchaseStatus.purchased) {
        verify(() => store.completePurchase(terminal)).called(1);
      } else {
        verifyNever(() => store.completePurchase(any()));
      }
      expect(await service.purchase(TipItem.juice), isTrue);
    });
  }

  test('iOSのIDなしpending解消は同じ商品の識別済み別取引を解除しない', () async {
    start();
    final knownPending = sk2Purchase('known-pending', PurchaseStatus.pending);
    events.add([knownPending, sk2Purchase(null, PurchaseStatus.pending)]);
    await drain();
    final approved = sk2Purchase('newly-approved', PurchaseStatus.purchased);
    events.add([approved]);
    await drain();
    expect(service.pendingItem, TipItem.juice);
    expect(updates.last.type, TipPurchaseUpdateType.completed);
    events.add([sk2Purchase('known-pending', PurchaseStatus.purchased)]);
    await drain();
    expect(service.pendingItem, isNull);
  });

  test('StoreKit1のIDなしpendingはreceiptが変わった失敗でも解消する', () async {
    AppStorePurchaseDetails details(
      SKPaymentTransactionStateWrapper status,
      String receipt,
    ) => AppStorePurchaseDetails.fromSKTransaction(
      SKPaymentTransactionWrapper(
        payment: SKPaymentWrapper(productIdentifier: TipItem.juice.productId),
        transactionState: status,
      ),
      receipt,
    );
    start();
    final pending = details(
      SKPaymentTransactionStateWrapper.deferred,
      'receipt-before',
    );
    expect(pending.purchaseID, isNull);
    expect(pending.status, PurchaseStatus.pending);
    events.add([pending]);
    await drain();
    final failed = details(
      SKPaymentTransactionStateWrapper.failed,
      'receipt-after',
    );
    expect(failed.purchaseID, isNull);
    expect(failed.pendingCompletePurchase, isTrue);
    events.add([failed]);
    await drain();
    verify(() => store.completePurchase(failed)).called(1);
    expect(service.pendingItem, isNull);
    expect(updates.last.type, TipPurchaseUpdateType.failed);
  });

  test('Androidは起動時に未消費取引を取得し、消費の成功を確認する', () async {
    final recovered = androidPurchase('recovered');
    when(() => android.queryPastPurchases()).thenAnswer(
      (_) async => QueryPurchaseDetailsResponse(pastPurchases: [recovered]),
    );
    start(isAndroid: true);
    await drain();
    verify(() => android.consumePurchase(recovered)).called(1);
    verifyNever(() => store.completePurchase(any()));
    expect(updates.last.type, TipPurchaseUpdateType.completed);
  });

  test('Androidの消費エラーを成功扱いせず再試行する', () async {
    start(isAndroid: true);
    await drain();
    final item = purchase('6', PurchaseStatus.purchased);
    when(() => android.consumePurchase(item)).thenAnswer(
      (_) async =>
          const BillingResultWrapper(responseCode: BillingResponse.error),
    );
    events.add([item]);
    await drain();
    expect(updates.last.type, TipPurchaseUpdateType.failed);
    expect(service.pendingItem, TipItem.juice);
    when(() => android.consumePurchase(item)).thenAnswer(
      (_) async => const BillingResultWrapper(responseCode: BillingResponse.ok),
    );
    await service.recoverPendingPurchases();
    await drain();
    expect(updates.last.type, TipPurchaseUpdateType.completed);
  });

  test('Androidの消費応答喪失後はtoken不在を再確認して未確認として閉塞を解除する', () async {
    // Reproduce the lost-response boundary without a real purchase. The fake
    // store consumes the token, then reports that it is not owned.
    final item = androidPurchase('consume-response-lost');
    var storeOwnsToken = false;
    var consumeAttempts = 0;
    final products = TipItem.values
        .map(
          (tip) => ProductDetails(
            id: tip.productId,
            title: 'tip',
            description: 'tip',
            price: '¥160',
            rawPrice: 160,
            currencyCode: 'JPY',
          ),
        )
        .toList();
    when(() => store.queryProductDetails(any())).thenAnswer(
      (_) async =>
          ProductDetailsResponse(productDetails: products, notFoundIDs: []),
    );
    when(
      () => store.buyConsumable(
        purchaseParam: any(named: 'purchaseParam'),
        autoConsume: false,
      ),
    ).thenAnswer((_) async => true);
    when(() => android.queryPastPurchases()).thenAnswer((_) async {
      expect(storeOwnsToken, isFalse);
      return QueryPurchaseDetailsResponse(pastPurchases: []);
    });
    when(() => android.consumePurchase(item)).thenAnswer((_) async {
      consumeAttempts++;
      if (consumeAttempts == 1) {
        expect(storeOwnsToken, isTrue);
        storeOwnsToken = false;
        return const BillingResultWrapper(responseCode: BillingResponse.error);
      }
      expect(storeOwnsToken, isFalse);
      return const BillingResultWrapper(
        responseCode: BillingResponse.itemNotOwned,
      );
    });
    start(isAndroid: true);
    await drain();
    final catalog = await service.loadCatalog();
    expect(catalog.prices, hasLength(TipItem.values.length));

    storeOwnsToken = true;
    events.add([item]);
    await drain();
    expect(storeOwnsToken, isFalse);
    expect(service.pendingItem, TipItem.juice);
    expect(updates.last.type, TipPurchaseUpdateType.failed);

    // The first retry checks absence again after ITEM_NOT_OWNED. Later retries
    // must not keep consuming the now-terminal token or claim a successful tip.
    for (var retry = 0; retry < 3; retry++) {
      await service.recoverPendingPurchases();
      await drain();
      expect(service.pendingItem, isNull);
      expect(updates.last.type, TipPurchaseUpdateType.unconfirmed);
    }
    expect(consumeAttempts, 2);
    verify(() => android.queryPastPurchases()).called(5);
    expect(
      updates.where((update) => update.type == TipPurchaseUpdateType.completed),
      isEmpty,
    );
    verifyNever(
      () => store.buyConsumable(
        purchaseParam: any(named: 'purchaseParam'),
        autoConsume: false,
      ),
    );

    // A delayed duplicate with a different order ID is still the same token.
    final delayed = androidPurchase(
      'late-order-id',
      token: item.verificationData.serverVerificationData,
    );
    events.add([delayed]);
    await drain();
    expect(service.pendingItem, isNull);
    expect(consumeAttempts, 2);
    expect(updates.last.type, TipPurchaseUpdateType.unconfirmed);

    // Only an explicit new purchase may start. A different token is not blocked.
    expect(await service.purchase(TipItem.juice), isTrue);
    final next = androidPurchase('next-purchase-token');
    events.add([next]);
    await drain();
    verify(() => android.consumePurchase(next)).called(1);
    expect(service.pendingItem, isNull);
    expect(updates.last.type, TipPurchaseUpdateType.completed);
  });

  for (final response in ['still-owned', 'query-error', 'missing-token']) {
    test('Androidの未所有応答でも$responseなら未完了のまま再試行する', () async {
      start(isAndroid: true);
      await drain();
      final item = androidPurchase(
        'unresolved',
        token: response == 'missing-token' ? '' : null,
      );
      final owned = androidPurchase(
        'different-order-id',
        token: item.verificationData.serverVerificationData,
      );
      when(() => android.queryPastPurchases()).thenAnswer(
        (_) async => QueryPurchaseDetailsResponse(
          pastPurchases: response == 'still-owned' ? [owned] : [],
          error: response == 'query-error'
              ? IAPError(source: 'test', code: 'query-error', message: 'failed')
              : null,
        ),
      );
      when(() => android.consumePurchase(any())).thenAnswer(
        (_) async => const BillingResultWrapper(
          responseCode: BillingResponse.itemNotOwned,
        ),
      );
      events.add([item]);
      await drain();
      expect(service.pendingItem, TipItem.juice);
      expect(updates.last.type, TipPurchaseUpdateType.failed);
      await service.recoverPendingPurchases();
      await drain();
      expect(service.pendingItem, TipItem.juice);
      expect(updates.last.type, TipPurchaseUpdateType.failed);
      expect(
        updates.where(
          (update) =>
              update.type == TipPurchaseUpdateType.completed ||
              update.type == TipPurchaseUpdateType.unconfirmed,
        ),
        isEmpty,
      );
    });
  }

  test('Androidの未所有判定は同じ商品でもtokenを区別する', () async {
    start(isAndroid: true);
    await drain();
    final missing = androidPurchase('missing-token');
    final other = androidPurchase('other-owned-token');
    when(() => android.queryPastPurchases()).thenAnswer(
      (_) async => QueryPurchaseDetailsResponse(pastPurchases: [other]),
    );
    when(() => android.consumePurchase(missing)).thenAnswer(
      (_) async => const BillingResultWrapper(
        responseCode: BillingResponse.itemNotOwned,
      ),
    );
    events.add([missing]);
    await drain();
    expect(service.pendingItem, isNull);
    expect(updates.last.type, TipPurchaseUpdateType.unconfirmed);
    events.add([other]);
    await drain();
    verify(() => android.consumePurchase(other)).called(1);
    expect(service.pendingItem, isNull);
    expect(updates.last.type, TipPurchaseUpdateType.completed);
  });

  for (final sameProduct in [true, false]) {
    test(
      'Androidの1取引の未確認終了は他のpendingを解除しない sameProduct=$sameProduct',
      () async {
        start(isAndroid: true);
        await drain();
        final missing = androidPurchase('old-token');
        final pendingTip = sameProduct ? TipItem.juice : TipItem.coffee;
        final pending = androidPurchase(
          'new-pending-token',
          tip: pendingTip,
          status: PurchaseStatus.pending,
        );
        when(() => android.queryPastPurchases()).thenAnswer(
          (_) async => QueryPurchaseDetailsResponse(pastPurchases: [pending]),
        );
        when(() => android.consumePurchase(missing)).thenAnswer(
          (_) async => const BillingResultWrapper(
            responseCode: BillingResponse.itemNotOwned,
          ),
        );
        events.add([pending, missing]);
        await drain();
        expect(updates.last.type, TipPurchaseUpdateType.unconfirmed);
        expect(service.pendingItem, pendingTip);
        final completed = androidPurchase(
          'new-order-id',
          tip: pendingTip,
          token: pending.verificationData.serverVerificationData,
        );
        events.add([completed]);
        await drain();
        expect(service.pendingItem, isNull);
        expect(updates.last.type, TipPurchaseUpdateType.completed);
      },
    );
  }

  test('商品未取得・ストア利用不能なら価格なしで購入を拒否する', () async {
    start();
    when(() => store.isAvailable()).thenAnswer((_) async => false);
    final catalog = await service.loadCatalog();
    expect(catalog.isStoreAvailable, false);
    expect(catalog.prices, isEmpty);
    expect(await service.purchase(TipItem.juice), false);
  });

  test('同じ消耗商品は別取引なら再度完了できる', () async {
    start();
    events.add([purchase('7a', PurchaseStatus.purchased)]);
    events.add([purchase('7b', PurchaseStatus.purchased)]);
    await drain();
    expect(
      updates.where((u) => u.type == TipPurchaseUpdateType.completed),
      hasLength(2),
    );
  });

  test('ストア価格を使い、Android購入を手動消費にして二重開始を防ぐ', () async {
    final product = ProductDetails(
      id: TipItem.juice.productId,
      title: 'tip',
      description: 'tip',
      price: '¥160',
      rawPrice: 160,
      currencyCode: 'JPY',
    );
    when(() => store.queryProductDetails(any())).thenAnswer(
      (_) async =>
          ProductDetailsResponse(productDetails: [product], notFoundIDs: []),
    );
    when(
      () => store.buyConsumable(
        purchaseParam: any(named: 'purchaseParam'),
        autoConsume: false,
      ),
    ).thenAnswer((_) async => true);
    start(isAndroid: true);
    final catalog = await service.loadCatalog();
    expect(catalog.prices[TipItem.juice], '¥160');
    expect(await service.purchase(TipItem.juice), true);
    expect(await service.purchase(TipItem.juice), false);
    verify(
      () => store.buyConsumable(
        purchaseParam: any(named: 'purchaseParam'),
        autoConsume: false,
      ),
    ).called(1);
  });

  test('購入開始が拒否・例外になっても購入中状態を解除する', () async {
    final product = ProductDetails(
      id: TipItem.juice.productId,
      title: 'tip',
      description: 'tip',
      price: '¥160',
      rawPrice: 160,
      currencyCode: 'JPY',
    );
    when(() => store.queryProductDetails(any())).thenAnswer(
      (_) async =>
          ProductDetailsResponse(productDetails: [product], notFoundIDs: []),
    );
    when(
      () => store.buyConsumable(purchaseParam: any(named: 'purchaseParam')),
    ).thenAnswer((_) async => false);
    start();
    await service.loadCatalog();
    expect(await service.purchase(TipItem.juice), false);
    expect(service.pendingItem, isNull);
    expect(service.latestUpdate?.type, TipPurchaseUpdateType.failed);
    when(
      () => store.buyConsumable(purchaseParam: any(named: 'purchaseParam')),
    ).thenThrow(StateError('ストアの開始失敗'));
    expect(await service.purchase(TipItem.juice), false);
    expect(service.pendingItem, isNull);
    expect(service.latestUpdate?.type, TipPurchaseUpdateType.failed);
  });

  test('Androidの古い購入開始返答は取消後に開始した購入を解除しない', () async {
    start(isAndroid: true);
    await drain();
    final product = ProductDetails(
      id: TipItem.juice.productId,
      title: 'tip',
      description: 'tip',
      price: '¥160',
      rawPrice: 160,
      currencyCode: 'JPY',
    );
    when(() => store.queryProductDetails(any())).thenAnswer(
      (_) async =>
          ProductDetailsResponse(productDetails: [product], notFoundIDs: []),
    );
    final first = Completer<bool>();
    var attempts = 0;
    when(
      () => store.buyConsumable(
        purchaseParam: any(named: 'purchaseParam'),
        autoConsume: false,
      ),
    ).thenAnswer((_) => attempts++ == 0 ? first.future : Future.value(true));
    await service.loadCatalog();
    final oldPurchase = service.purchase(TipItem.juice);
    events.add([
      PurchaseDetails(
        purchaseID: '',
        productID: '',
        status: PurchaseStatus.canceled,
        transactionDate: null,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: 'google_play',
        ),
      ),
    ]);
    await drain();
    expect(service.pendingItem, isNull);
    expect(await service.purchase(TipItem.juice), isTrue);
    first.complete(false);
    expect(await oldPurchase, isFalse);
    expect(service.pendingItem, TipItem.juice);
    expect(service.latestUpdate?.type, TipPurchaseUpdateType.pending);
  });

  for (final status in [PurchaseStatus.canceled, PurchaseStatus.error]) {
    test('Androidの空商品IDの$statusは今回開始した購入だけを解除する', () async {
      start(isAndroid: true);
      await drain();
      final product = ProductDetails(
        id: TipItem.juice.productId,
        title: 'tip',
        description: 'tip',
        price: '¥160',
        rawPrice: 160,
        currencyCode: 'JPY',
      );
      when(() => store.queryProductDetails(any())).thenAnswer(
        (_) async =>
            ProductDetailsResponse(productDetails: [product], notFoundIDs: []),
      );
      when(
        () => store.buyConsumable(
          purchaseParam: any(named: 'purchaseParam'),
          autoConsume: false,
        ),
      ).thenAnswer((_) async => true);
      await service.loadCatalog();
      expect(await service.purchase(TipItem.juice), isTrue);
      events.add([
        PurchaseDetails(
          purchaseID: '',
          productID: '',
          status: status,
          transactionDate: null,
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: '',
            source: 'google_play',
          ),
        ),
      ]);
      await drain();
      expect(service.pendingItem, isNull);
      expect(
        updates.last.type,
        status == PurchaseStatus.canceled
            ? TipPurchaseUpdateType.canceled
            : TipPurchaseUpdateType.failed,
      );
      verifyNever(() => store.completePurchase(any()));
      expect(await service.purchase(TipItem.juice), isTrue);
    });
  }

  test('Androidの空商品ID取消はストアから既知のpendingを解除しない', () async {
    start(isAndroid: true);
    await drain();
    events.add([
      androidPurchase('deferred-token', status: PurchaseStatus.pending),
    ]);
    await drain();
    events.add([
      PurchaseDetails(
        purchaseID: '',
        productID: '',
        status: PurchaseStatus.canceled,
        transactionDate: null,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: 'google_play',
        ),
      ),
    ]);
    await drain();
    expect(service.pendingItem, TipItem.juice);
    expect(updates.last.type, TipPurchaseUpdateType.pending);
  });
}
