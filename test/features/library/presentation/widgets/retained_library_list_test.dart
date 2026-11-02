import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/widgets/media_list_view.dart';
import 'package:private_shelf/features/library/presentation/widgets/retained_library_list.dart';
import '../../../../helpers/test_helpers.dart';

void main() {
  setUp(setupMockSharedPreferences);
  testWidgets('検索で元の行と位置を保持し、非表示一覧をスクロールから切り離す', (tester) async {
    final items = List.generate(
      280,
      (i) => MediaItem()
        ..id = i + 1
        ..path = 'library/item_$i.txt',
    );
    var filter = const MediaFilter(rootOnly: true);
    late StateSetter update;
    late ScrollController primary;
    var loads = 0;
    var reloading = false;
    await tester.pumpWidget(
      createProviderApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return NestedScrollView(
              headerSliverBuilder: (_, _) => [
                const SliverAppBar(title: Text('Library')),
              ],
              body: Builder(
                builder: (context) {
                  primary = PrimaryScrollController.of(context);
                  return RetainedLibraryList(
                    filter: filter,
                    items: reloading
                        ? const AsyncLoading<List<MediaItem>>()
                        : AsyncData(
                            filter.searchQuery == null ? items : <MediaItem>[],
                          ),
                    fallback: ListView(
                      children: const [
                        SizedBox(height: 2000, child: Text('Search')),
                      ],
                    ),
                    onLoadMore: () => loads++,
                  );
                },
              ),
            );
          },
        ),
        overrides: [appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp')],
      ),
    );
    await tester.pumpAndSettle();
    final list = find.byType(MediaListView);
    final original = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    original.position.jumpTo(3000);
    await tester.pumpAndSettle();
    final pixels = original.position.pixels;
    final originalWidget = tester.widget<MediaListView>(list);
    expect(primary.positions.length, 1);
    update(() => filter = filter.copyWith(searchQuery: 'missing'));
    await tester.pumpAndSettle();
    expect(primary.positions.length, 1);
    final beforeLoads = loads;
    await tester.dragFrom(const Offset(400, 450), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(loads, beforeLoads);
    update(() {
      filter = filter.copyWith(searchQuery: null);
      reloading = true;
    });
    await tester.pumpAndSettle();
    final restored = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(restored, same(original));
    expect(tester.widget<MediaListView>(list), same(originalWidget));
    expect(restored.position.pixels, pixels);
    expect(primary.positions.length, 1);
    update(() => reloading = false);
    await tester.pumpAndSettle();
    expect(tester.widget<MediaListView>(list), same(originalWidget));
    update(() {
      items[0].path = 'library/renamed.txt';
      reloading = false;
    });
    await tester.pumpAndSettle();
    expect(tester.widget<MediaListView>(list), isNot(same(originalWidget)));
    expect(
      tester.widget<MediaListView>(list).items.first.path,
      'library/renamed.txt',
    );
    update(() {
      reloading = true;
      filter = filter.copyWith(parentPath: 'other');
    });
    await tester.pumpAndSettle();
    expect(find.byType(MediaListView, skipOffstage: false), findsNothing);
    update(() => reloading = false);
    await tester.pumpAndSettle();
    final changed = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(changed, isNot(same(original)));
    expect(tester.takeException(), isNull);
  });
}
