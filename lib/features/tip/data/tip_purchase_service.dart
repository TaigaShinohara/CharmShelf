import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/logger/log_tag.dart';
import '../domain/tip_item.dart';

class TipCatalog {
  const TipCatalog({
    required this.isStoreAvailable,
    required this.prices,
    this.hasLoadError = false,
  });

  final bool isStoreAvailable;
  final Map<TipItem, String> prices;
  final bool hasLoadError;
}

enum TipPurchaseUpdateType { pending, completed, canceled, failed, unconfirmed }

class TipPurchaseUpdate {
  const TipPurchaseUpdate({required this.item, required this.type});

  final TipItem? item;
  final TipPurchaseUpdateType type;
}

abstract interface class TipPurchaseService {
  Stream<TipPurchaseUpdate> get updates;

  TipPurchaseUpdate? get latestUpdate;

  Future<TipCatalog> loadCatalog();

  Future<bool> purchase(TipItem item);

  TipItem? get pendingItem;

  Future<void> recoverPendingPurchases();

  void dispose();
}

class StoreTipPurchaseService implements TipPurchaseService {
  StoreTipPurchaseService({
    InAppPurchase? store,
    bool? isAndroid,
    this._androidAddition,
    Future<List<PurchaseDetails>> Function()? unfinishedIosPurchases,
    this.retryDelay = const Duration(seconds: 30),
  }) : _store = store ?? InAppPurchase.instance,
       _isAndroid =
           isAndroid ?? defaultTargetPlatform == TargetPlatform.android,
       _unfinishedIosPurchases = unfinishedIosPurchases ?? _queryUnfinishedIos {
    _purchaseSubscription = _store.purchaseStream.listen(
      (purchases) => unawaited(_enqueue(purchases)),
      onError: (Object error, StackTrace stackTrace) {
        // ストア例外には取引・検証情報が含まれ得るため本文を記録しない。
        AppLogger.w(LogTag.app, '課金ストリームの再接続が必要です');
        _emit(null, TipPurchaseUpdateType.failed);
        _scheduleRetry();
      },
    );
    unawaited(recoverPendingPurchases());
  }

  final InAppPurchase _store;
  final bool _isAndroid;
  final InAppPurchaseAndroidPlatformAddition? _androidAddition;
  final Future<List<PurchaseDetails>> Function() _unfinishedIosPurchases;

  static Future<List<PurchaseDetails>> _queryUnfinishedIos() async {
    // StoreKit 1は起動時のqueue observerが未完了取引を再送する。
    if (!InAppPurchaseStoreKitPlatform.isStoreKit2Enabled) return [];
    final transactions = await SK2Transaction.unfinishedTransactions();
    return transactions
        .map(
          (transaction) => SK2PurchaseDetails(
            purchaseID: transaction.id,
            productID: transaction.productId,
            verificationData: PurchaseVerificationData(
              localVerificationData: transaction.jsonRepresentation ?? '',
              serverVerificationData: transaction.receiptData ?? '',
              source: 'app_store',
            ),
            transactionDate: transaction.purchaseDate,
            status: PurchaseStatus.purchased,
          ),
        )
        .toList();
  }

  final Duration retryDelay;
  final _updates = StreamController<TipPurchaseUpdate>.broadcast();
  final Map<String, ProductDetails> _products = {};
  final Map<String, PurchaseDetails> _unfinished = {};
  final Set<String> _terminal = {};
  final Set<TipItem> _pendingItems = {};
  final Map<String, TipItem> _pendingTransactions = {};
  final Set<TipItem> _unidentifiedIosPendingItems = {};
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;
  Future<void> _processing = Future.value();
  Future<void>? _recovery;
  Timer? _retryTimer;
  bool _disposed = false;
  TipPurchaseUpdate? _latestUpdate;
  TipItem? _startingItem;
  int _purchaseGeneration = 0;

  @override
  Stream<TipPurchaseUpdate> get updates => _updates.stream;

  @override
  TipPurchaseUpdate? get latestUpdate => _latestUpdate;

  @override
  TipItem? get pendingItem =>
      _pendingItems.isEmpty ? null : _pendingItems.first;

  void _emit(TipItem? item, TipPurchaseUpdateType type) {
    if (_disposed) return;
    final update = TipPurchaseUpdate(item: item, type: type);
    _latestUpdate = update;
    _updates.add(update);
  }

  @override
  Future<TipCatalog> loadCatalog() async {
    _products.clear();
    try {
      if (!await _store.isAvailable() || _disposed) {
        return const TipCatalog(isStoreAvailable: false, prices: {});
      }
      final response = await _store.queryProductDetails(
        TipItem.values.map((item) => item.productId).toSet(),
      );
      if (_disposed) {
        return const TipCatalog(isStoreAvailable: false, prices: {});
      }
      _products.addEntries(
        response.productDetails.map((p) => MapEntry(p.id, p)),
      );
      return TipCatalog(
        isStoreAvailable: true,
        prices: {
          for (final item in TipItem.values)
            if (_products[item.productId] case final product?)
              item: product.price,
        },
        hasLoadError: response.error != null,
      );
    } catch (error) {
      AppLogger.w(LogTag.app, 'チップ商品の取得に失敗しました');
      return const TipCatalog(
        isStoreAvailable: false,
        prices: {},
        hasLoadError: true,
      );
    }
  }

  @override
  Future<bool> purchase(TipItem item) async {
    final product = _products[item.productId];
    if (_disposed || product == null || _pendingItems.isNotEmpty) return false;
    final generation = ++_purchaseGeneration;
    _startingItem = item;
    _pendingItems.add(item);
    _emit(item, TipPurchaseUpdateType.pending);
    try {
      final started = await _store.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
        // Androidは再起動後の未消費取引も同じ経路で明示的に消費する。
        autoConsume: !_isAndroid,
      );
      if (!started) _clearStartingPurchase(generation, item);
      return started;
    } catch (error) {
      _clearStartingPurchase(generation, item);
      AppLogger.w(LogTag.app, 'チップ購入画面の開始に失敗しました');
      return false;
    }
  }

  @override
  Future<void> recoverPendingPurchases() {
    if (_disposed) return Future.value();
    return _recovery ??= _recover().whenComplete(() => _recovery = null);
  }

  Future<void> _recover() async {
    try {
      if (_disposed) return;
      if (!await _store.isAvailable()) {
        _scheduleRetry();
        return;
      }
      // Androidのストアを永続的な未消費取引の正本として照会する。
      // 自動restoreによる認証ダイアログは表示しない。
      if (_isAndroid) {
        final addition =
            _androidAddition ??
            _store.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        final response = await addition.queryPastPurchases();
        if (response.error != null) throw StateError('未完了取引の照会失敗');
        await _enqueue(response.pastPurchases);
      } else {
        await _enqueue(await _unfinishedIosPurchases());
      }
      await _enqueue(_unfinished.values.toList());
    } catch (error) {
      AppLogger.w(LogTag.app, '未完了のチップ購入を再取得できませんでした');
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_disposed || _retryTimer != null) return;
    _retryTimer = Timer(retryDelay, () {
      _retryTimer = null;
      unawaited(recoverPendingPurchases());
    });
  }

  Future<void> _enqueue(List<PurchaseDetails> purchases) {
    return _processing = _processing.then((_) async {
      if (!_disposed) await _handlePurchases(purchases);
    });
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (_disposed) return;
      final item = TipItem.fromProductId(purchase.productID);
      if (item == null) {
        // Android's SDK uses an empty product ID when the purchase sheet closes
        // without a purchase list. It belongs only to our current launch attempt,
        // not to a different pending transaction recovered from the store.
        final starting = _startingItem;
        if (_isAndroid &&
            starting != null &&
            purchase.productID.isEmpty &&
            (purchase.status == PurchaseStatus.canceled ||
                purchase.status == PurchaseStatus.error)) {
          _startingItem = null;
          _clearPendingItem(starting);
          _emit(
            starting,
            purchase.status == PurchaseStatus.canceled
                ? TipPurchaseUpdateType.canceled
                : TipPurchaseUpdateType.failed,
          );
        }
        continue;
      }
      final token = purchase.verificationData.serverVerificationData;
      // Android's token is stable across callbacks even when order IDs change.
      final identity = _isAndroid && token.isNotEmpty
          ? token
          : purchase.purchaseID ?? token;
      final key = '${purchase.productID}:$identity';
      if (_terminal.contains(key)) continue;
      if (_startingItem == item) _startingItem = null;
      if (purchase.status == PurchaseStatus.pending) {
        // StoreKit pending/cancelled notifications can have no transaction ID.
        // Their receipt is absent in SK2 or app-wide/mutable in SK1; it cannot
        // correlate them with the real ID supplied after purchase approval.
        if (!_isAndroid &&
            (purchase.purchaseID == null || purchase.purchaseID!.isEmpty)) {
          _unidentifiedIosPendingItems.add(item);
        } else {
          _pendingTransactions[key] = item;
        }
        _pendingItems.add(item);
        _emit(item, TipPurchaseUpdateType.pending);
        continue;
      }
      final completed =
          purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored;
      try {
        if (completed) {
          _pendingTransactions[key] = item;
          _pendingItems.add(item);
          _unfinished[key] = purchase;
          if (_isAndroid) {
            final addition =
                _androidAddition ??
                _store
                    .getPlatformAddition<
                      InAppPurchaseAndroidPlatformAddition
                    >();
            final result = await addition.consumePurchase(purchase);
            if (result.responseCode == BillingResponse.itemNotOwned &&
                await _androidTokenIsAbsent(purchase, addition)) {
              // Absence cannot distinguish consumption, refund or revocation.
              // Stop replaying this token without claiming purchase completion.
              _unfinished.remove(key);
              _clearPendingTransaction(key, item);
              _recordTerminal(key);
              _emit(item, TipPurchaseUpdateType.unconfirmed);
              continue;
            }
            // 消費は承認も兼ねる。ストアの成功結果を確認する。
            if (result.responseCode != BillingResponse.ok) {
              throw StateError('チップ商品の消費を完了できませんでした');
            }
          } else if (purchase.pendingCompletePurchase) {
            await _store.completePurchase(purchase);
          }
        } else if (!_isAndroid && purchase.pendingCompletePurchase) {
          // StoreKit 1の取消・失敗取引にもfinishが必要。
          _unfinished[key] = purchase;
          await _store.completePurchase(purchase);
        }
        _unfinished.remove(key);
        _clearPendingTransaction(key, item);
        if (completed) {
          _recordTerminal(key);
        }
        _emit(
          item,
          completed
              ? TipPurchaseUpdateType.completed
              : purchase.status == PurchaseStatus.canceled
              ? TipPurchaseUpdateType.canceled
              : TipPurchaseUpdateType.failed,
        );
      } catch (error) {
        AppLogger.w(LogTag.app, 'チップ購入の完了処理を再試行します');
        _emit(item, TipPurchaseUpdateType.failed);
        _scheduleRetry();
      }
    }
  }

  Future<bool> _androidTokenIsAbsent(
    PurchaseDetails purchase,
    InAppPurchaseAndroidPlatformAddition addition,
  ) async {
    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) throw StateError('購入識別情報がありません');
    // queryPastPurchases returns GooglePlayPurchaseDetails. Compare the exact
    // product/token pair, not the order ID or product alone. Never log tokens.
    final response = await addition.queryPastPurchases();
    if (response.error != null) throw StateError('未完了取引の照会失敗');
    return !response.pastPurchases.any(
      (owned) =>
          owned.productID == purchase.productID &&
          owned.verificationData.serverVerificationData == token,
    );
  }

  void _recordTerminal(String key) {
    _terminal.add(key);
    if (_terminal.length > 256) _terminal.remove(_terminal.first);
  }

  void _clearPendingTransaction(String key, TipItem item) {
    _pendingTransactions.remove(key);
    if (!_isAndroid) _unidentifiedIosPendingItems.remove(item);
    _clearPendingItem(item);
  }

  void _clearStartingPurchase(int generation, TipItem item) {
    if (generation != _purchaseGeneration) return;
    // A native terminal notification or a newer attempt already owns the state.
    if (_startingItem != item) return;
    _startingItem = null;
    _clearPendingItem(item);
    _emit(item, TipPurchaseUpdateType.failed);
  }

  void _clearPendingItem(TipItem item) {
    // Settling one transaction must not hide another pending token for this tip.
    if (!_pendingTransactions.containsValue(item) &&
        !_unidentifiedIosPendingItems.contains(item)) {
      _pendingItems.remove(item);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retryTimer?.cancel();
    unawaited(_close());
  }

  Future<void> _close() async {
    await _purchaseSubscription.cancel();
    await _processing;
    await _updates.close();
  }
}
