import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';

void main() {
  test('Search query updates performance with 10000 rapid inputs', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final stopwatch = Stopwatch()..start();

    // update query multiple times to simulate typing
    for (var i = 0; i < 10000; i++) {
      container
          .read(mediaFilterNotifierProvider(AppMode.internal).notifier)
          .updateSearchQuery('query $i');
    }

    stopwatch.stop();

    final finalQuery = container
        .read(mediaFilterNotifierProvider(AppMode.internal))
        .searchQuery;

    expect(finalQuery, 'query 9999');
    expect(
      stopwatch.elapsedMilliseconds,
      lessThan(1000),
      reason:
          'Search update for 10000 inputs should not block main thread significantly',
    );
  });
}
