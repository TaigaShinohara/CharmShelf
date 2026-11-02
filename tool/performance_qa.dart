// Build only with ORG_GRADLE_PROJECT_tagshelfPerformanceQa=true.
// Uses the real app and repository, but refuses to seed the normal package.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/main.dart' as app;
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/core/services/private_storage_service.dart';
import 'package:private_shelf/features/library/data/repositories/isar_media_repository.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';

import 'performance_qa_package.dart';

void emit(Map<String, Object?> values) {
  // ignore: avoid_print
  print('TAGSHELF_PERF ${jsonEncode(values)}');
}

class _ProbeBinding extends WidgetsFlutterBinding {
  int pointers = 0;
  @override
  void handlePointerEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      final id = ++pointers;
      final watch = Stopwatch()..start();
      addPostFrameCallback((_) {
        // This is next-frame latency, not proof that the intended content is ready.
        emit({
          'kind': 'pointer_next_frame',
          'id': id,
          'us': watch.elapsedMicroseconds,
        });
      });
    }
    super.handlePointerEvent(event);
  }
}

Future<void> main() async {
  final binding = _ProbeBinding();
  // Use only for attribution, never for before/after frame-budget comparisons:
  // recording every build/layout/paint adds significant profiling overhead.
  const detailedTrace = bool.fromEnvironment('TAGSHELF_DETAILED_TRACE');
  debugProfileBuildsEnabled = detailedTrace;
  debugProfileLayoutsEnabled = detailedTrace;
  debugProfilePaintsEnabled = detailedTrace;
  final package = await PackageInfo.fromPlatform();
  requirePerformanceQaPackage(package.packageName);
  final dir = await PrivateStorageService.prepare();
  final container = ProviderContainer();
  final isar = await container.read(isarProvider.future);
  if (await isar.mediaItems.count() == 0) {
    final root = Directory('${dir.path}/library/performance');
    final catalog = Directory('${root.path}/catalog');
    await catalog.create(recursive: true);
    final pictures = <List<int>>[];
    for (final name in [
      'moonlit_reader',
      'botanical_atelier',
      'starlight_observatory',
    ]) {
      final bytes = await rootBundle.load(
        'assets/images/samples/illustration_collection/$name.png',
      );
      pictures.add(bytes.buffer.asUint8List());
    }
    final folder = MediaItem()
      ..uid = 'qa-catalog'
      ..path = 'library/performance/catalog'
      ..type = MediaType.folder
      ..addedAt = DateTime(2026, 1, 1);
    final items = <MediaItem>[folder];
    // 7,999 loose text files + one catalog + 2,000 catalog files = 10,000.
    for (var start = 0; start < 9999; start += 32) {
      await Future.wait([
        for (var i = start; i < start + 32 && i < 9999; i++)
          () async {
            final inCatalog = i >= 7999;
            final index = inCatalog ? i - 7999 : i;
            final image = inCatalog && index < 60;
            final path =
                'library/performance/${inCatalog ? 'catalog/' : ''}'
                '${index.toString().padLeft(5, '0')}.${image ? 'png' : 'txt'}';
            final file = File('${dir.path}/$path');
            if (image) {
              await file.writeAsBytes(pictures[index % pictures.length]);
            } else {
              await file.writeAsString(
                'Performance fixture $index\nLocal text content.\n',
              );
            }
            items.add(
              MediaItem()
                ..uid = 'qa-$i'
                ..path = path
                ..parentPath = inCatalog ? folder.path : null
                ..addedAt = DateTime(2026).add(Duration(seconds: i))
                ..size = await file.length(),
            );
          }(),
      ]);
    }
    final collection = MediaCollection()
      ..uid = 'qa-collection'
      ..path = folder.path
      ..title = '性能検証・2000ファイル'
      ..isCatalog = true
      ..defaultSortOrder = SortOrder.nameAsc
      ..coverImagePath = '${folder.path}/00000.png';
    await isar.writeTxn(() async {
      await isar.mediaItems.putAll(items);
      collection.lastViewedItemId = items
          .firstWhere((i) => i.path.endsWith('catalog/00030.png'))
          .id;
      await isar.mediaCollections.put(collection);
    });
  }
  final prefs = await SharedPreferences.getInstance();
  for (final key in [
    'onboarding_completed',
    'restore_prompt_handled',
    'tag_presets_initialized',
    'template_collection_initialized',
  ]) {
    await prefs.setBool(key, true);
  }
  final repository = IsarMediaRepository(isar);
  final durations = <int>[];
  for (var i = 0; i < 5; i++) {
    final watch = Stopwatch()..start();
    final result = await repository.getAll(
      filter: const MediaFilter(rootOnly: true, limit: 80),
    );
    if (result.isFailure || result.dataOrNull!.length != 80) {
      throw StateError('Invalid fixture result');
    }
    durations.add(watch.elapsedMicroseconds);
  }
  emit({
    'kind': 'repository_first80',
    'count': await isar.mediaItems.count(),
    'us': durations,
  });
  final frames = <FrameTiming>[];
  binding.addTimingsCallback(frames.addAll);
  var window = 0;
  Timer.periodic(const Duration(seconds: 5), (_) {
    if (frames.isEmpty) return;
    final build = frames.map((f) => f.buildDuration.inMicroseconds).toList()
      ..sort();
    final raster = frames.map((f) => f.rasterDuration.inMicroseconds).toList()
      ..sort();
    int percentile(List<int> values) =>
        values[((values.length - 1) * .95).round()];
    emit({
      'kind': 'frames',
      'window': ++window,
      'count': frames.length,
      'build_p95_us': percentile(build),
      'raster_p95_us': percentile(raster),
      'build_max_us': build.last,
      'raster_max_us': raster.last,
      'over_16ms': frames
          .where(
            (f) =>
                f.buildDuration.inMicroseconds > 16667 ||
                f.rasterDuration.inMicroseconds > 16667,
          )
          .length,
      'over_8ms': frames
          .where(
            (f) =>
                f.buildDuration.inMicroseconds > 8333 ||
                f.rasterDuration.inMicroseconds > 8333,
          )
          .length,
    });
    frames.clear();
  });
  app.main();
}
