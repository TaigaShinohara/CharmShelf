import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/tip_purchase_service.dart';
import '../../../../core/services/app_lifecycle_service.dart';
import '../../domain/tip_item.dart';

part 'tip_purchase_provider.g.dart';

@Riverpod(keepAlive: true)
TipPurchaseService tipPurchaseService(Ref ref) {
  final service = StoreTipPurchaseService();
  ref.onDispose(service.dispose);
  ref.listen(appLifecycleProvider, (previous, next) {
    if (next == AppLifecycleStatus.foreground) {
      unawaited(service.recoverPendingPurchases());
    }
  });
  return service;
}

class TipPurchaseState {
  const TipPurchaseState({
    required this.catalog,
    this.pendingItem,
    this.completedItem,
    this.event = TipPurchaseUpdateType.canceled,
  });

  final TipCatalog catalog;
  final TipItem? pendingItem;
  final TipItem? completedItem;
  final TipPurchaseUpdateType event;

  TipPurchaseState copyWith({
    TipItem? pendingItem,
    bool clearPendingItem = false,
    TipItem? completedItem,
    bool clearCompletedItem = false,
    TipPurchaseUpdateType? event,
  }) {
    return TipPurchaseState(
      catalog: catalog,
      pendingItem: clearPendingItem ? null : (pendingItem ?? this.pendingItem),
      completedItem: clearCompletedItem
          ? null
          : completedItem ?? this.completedItem,
      event: event ?? this.event,
    );
  }
}

@Riverpod(keepAlive: true)
class TipPurchase extends _$TipPurchase {
  bool _active = false;
  int _generation = 0;
  int _purchaseAttempt = 0;

  @override
  Future<TipPurchaseState> build() async {
    _generation++;
    final service = ref.watch(tipPurchaseServiceProvider);
    _active = true;
    final subscription = service.updates.listen((update) {
      _handleUpdate(update);
    });
    ref.onDispose(() {
      _active = false;
      unawaited(subscription.cancel());
    });
    final catalog = await service.loadCatalog();
    final latestUpdate = service.latestUpdate;
    return TipPurchaseState(
      catalog: catalog,
      pendingItem: service.pendingItem,
      completedItem: latestUpdate?.type == TipPurchaseUpdateType.completed
          ? latestUpdate?.item
          : null,
      event: latestUpdate?.type ?? TipPurchaseUpdateType.canceled,
    );
  }

  Future<void> purchase(TipItem item) async {
    final generation = _generation;
    final current = state.value;
    if (current == null || current.pendingItem != null) return;
    if (!current.catalog.prices.containsKey(item)) return;
    final attempt = ++_purchaseAttempt;

    state = AsyncData(
      current.copyWith(
        pendingItem: item,
        clearCompletedItem: true,
        event: TipPurchaseUpdateType.pending,
      ),
    );

    final service = ref.read(tipPurchaseServiceProvider);
    final started = await service.purchase(item);
    if (!_active || generation != _generation || attempt != _purchaseAttempt) {
      return;
    }
    if (!started) {
      final latest = state.value;
      if (latest == null) return;
      final pending = service.pendingItem;
      final launchFailed =
          latest.event == TipPurchaseUpdateType.pending && pending == null;
      state = AsyncData(
        latest.copyWith(
          pendingItem: pending,
          clearPendingItem: pending == null,
          event: launchFailed ? TipPurchaseUpdateType.failed : latest.event,
        ),
      );
    }
  }

  void retry() {
    unawaited(ref.read(tipPurchaseServiceProvider).recoverPendingPurchases());
    ref.invalidateSelf();
  }

  void _handleUpdate(TipPurchaseUpdate update) {
    if (!_active) return;
    final current = state.value;
    if (current == null) return;

    final pending = ref.read(tipPurchaseServiceProvider).pendingItem;
    state = AsyncData(
      current.copyWith(
        pendingItem: pending,
        clearPendingItem: pending == null,
        completedItem: update.type == TipPurchaseUpdateType.completed
            ? update.item
            : null,
        clearCompletedItem: update.type != TipPurchaseUpdateType.completed,
        event: update.type,
      ),
    );
  }
}
