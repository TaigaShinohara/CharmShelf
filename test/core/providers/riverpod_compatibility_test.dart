import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/app/fresh_start_scope.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/player_notifier.dart';
import 'package:private_shelf/features/tip/data/tip_purchase_service.dart';
import 'package:private_shelf/features/tip/domain/tip_item.dart';
import 'package:private_shelf/features/tip/presentation/providers/tip_purchase_provider.dart';

class _PurchaseService implements TipPurchaseService {
  final events = StreamController<TipPurchaseUpdate>.broadcast(sync: true);

  @override
  Stream<TipPurchaseUpdate> get updates => events.stream;
  @override
  TipPurchaseUpdate? latestUpdate;
  @override
  TipItem? pendingItem;
  @override
  Future<TipCatalog> loadCatalog() async =>
      const TipCatalog(isStoreAvailable: true, prices: {});
  @override
  Future<bool> purchase(TipItem item) async => false;
  @override
  Future<void> recoverPendingPurchases() async {}
  @override
  void dispose() => unawaited(events.close());
}

class _LifecyclePlayer extends PlayerNotifier {
  int pauseCalls = 0;
  bool get isPaused => ref.isPaused;

  @override
  PlayerState build() {
    super.build();
    return PlayerState(
      currentItem: MediaItem()..path = 'synthetic.mp4',
      isPlaying: true,
    );
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    state = state.copyWith(isPlaying: false);
  }
}

void main() {
  testWidgets(
    'application scope retains explicit recovery after provider error',
    (tester) async {
      var attempts = 0;
      final failing = FutureProvider<int>((ref) async {
        attempts++;
        throw StateError('synthetic failure');
      });
      late ProviderContainer container;
      await tester.pumpWidget(
        FreshStartScope(
          overrides: const [],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                final result = ref.watch(failing);
                return Text(result.hasError ? 'failed' : 'loading');
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('failed'), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(attempts, 1, reason: '3.x automatic retries must stay disabled');
      container.invalidate(failing);
      await tester.pump();
      await tester.pump();
      expect(
        attempts,
        2,
        reason: 'explicit retry must still re-run the provider',
      );
    },
  );

  test(
    'purchase updates are processed while a page listener is paused',
    () async {
      final service = _PurchaseService();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [tipPurchaseServiceProvider.overrideWith((ref) => service)],
      );
      addTearDown(container.dispose);
      addTearDown(service.dispose);
      final subscription = container.listen(tipPurchaseProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(tipPurchaseProvider.future);
      subscription.pause();
      await container.pump();

      const event = TipPurchaseUpdate(
        item: TipItem.juice,
        type: TipPurchaseUpdateType.completed,
      );
      service.latestUpdate = event;
      service.events.add(event);
      await container.pump();
      expect(
        container.read(tipPurchaseProvider).value!.event,
        TipPurchaseUpdateType.completed,
      );
      expect(service.events.hasListener, isTrue);
      subscription.resume();
      await container.pump();
      expect(
        container.read(tipPurchaseProvider).value!.event,
        TipPurchaseUpdateType.completed,
      );
    },
  );

  testWidgets(
    'video receives background lifecycle while page listener is paused',
    (tester) async {
      final player = _LifecyclePlayer();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [playerNotifierProvider.overrideWith(() => player)],
      );
      final subscription = container.listen(playerNotifierProvider, (_, _) {});
      try {
        subscription.pause();
        await container.pump();
        expect(player.isPaused, isTrue);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(player.pauseCalls, 1);
        expect(container.read(playerNotifierProvider).isPlaying, isFalse);
      } finally {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        subscription.close();
        container.dispose();
      }
    },
  );
}
