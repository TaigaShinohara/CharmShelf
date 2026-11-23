import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/library_view_model.dart';
import 'package:private_shelf/features/library/presentation/providers/media_filter_provider.dart';
import 'package:private_shelf/features/settings/presentation/providers/app_mode_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/internal_library_screen.dart';

import '../helpers/test_helpers.dart';

class _AllMediaFilterNotifier extends MediaFilterNotifier {
  @override
  MediaFilter build(AppMode mode) {
    return MediaFilter(
      rootOnly: true,
      onlyCatalogs: false,
      sourceType: mode == AppMode.internal
          ? MediaSourceType.localCopy
          : MediaSourceType.externalReference,
    );
  }
}

class _LibraryViewModelWithItems extends LibraryViewModel {
  _LibraryViewModelWithItems(this.items);

  final List<MediaItem> items;

  @override
  FutureOr<List<MediaItem>> build() => items;
}

List<MediaItem> _sampleItems(int count) {
  return List<MediaItem>.generate(count, (index) {
    return MediaItem()
      ..id = index + 1
      ..path = 'library/item_$index.jpg'
      ..originalPath = '/tmp/item_$index.jpg'
      ..sourceType = MediaSourceType.localCopy
      ..type = MediaType.file
      ..parentPath = null;
  });
}

void main() {
  setUp(() {
    setupMockSharedPreferences();
  });

  Future<void> pumpLibrary(
    WidgetTester tester, {
    required List<MediaItem> items,
    Locale locale = const Locale('ja'),
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      createProviderApp(
        const InternalLibraryScreen(),
        locale: locale,
        overrides: [
          hapticsEnabledProvider.overrideWith((ref) => false),
          mediaFilterNotifierProvider(
            AppMode.internal,
          ).overrideWith(_AllMediaFilterNotifier.new),
          libraryViewModelProvider.overrideWith(
            () => _LibraryViewModelWithItems(items),
          ),
          appDocumentsPathSyncProvider.overrideWith((ref) => '/tmp'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('library empty ja (first screen after launch)', (tester) async {
    await pumpLibrary(tester, items: const []);
    await expectLater(
      find.byType(InternalLibraryScreen),
      matchesGoldenFile('goldens/goldens/library_empty_ja.png'),
    );
  }, tags: 'golden');

  testWidgets('library with items ja (first screen after launch)', (
    tester,
  ) async {
    await pumpLibrary(tester, items: _sampleItems(6));
    await expectLater(
      find.byType(InternalLibraryScreen),
      matchesGoldenFile('goldens/goldens/library_items_ja.png'),
    );
  }, tags: 'golden');

  testWidgets('library with items en (first screen after launch)', (
    tester,
  ) async {
    await pumpLibrary(
      tester,
      items: _sampleItems(6),
      locale: const Locale('en'),
    );
    await expectLater(
      find.byType(InternalLibraryScreen),
      matchesGoldenFile('goldens/goldens/library_items_en.png'),
    );
  }, tags: 'golden');
}
