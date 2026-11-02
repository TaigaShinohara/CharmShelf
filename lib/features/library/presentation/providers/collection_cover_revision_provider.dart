import 'dart:async';
import 'package:isar/isar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';

/// Observe only the catalog and its direct children, without loading them.
final collectionCoverRevisionProvider = StreamProvider.autoDispose
    .family<int, String>((ref, path) async* {
      final isar = await ref.watch(isarProvider.future);
      final items = isar.mediaItems
          .filter()
          .group((q) => q.pathEqualTo(path).or().parentPathEqualTo(path))
          .build();
      final catalogs = isar.mediaCollections.filter().pathEqualTo(path).build();
      yield* Stream<int>.multi((controller) {
        var revision = 0;
        final itemChanges = items.watchLazy().listen(
          (_) => controller.add(++revision),
          onError: controller.addError,
        );
        final catalogChanges = catalogs.watchLazy().listen(
          (_) => controller.add(++revision),
          onError: controller.addError,
        );
        controller.onCancel = () async {
          await itemChanges.cancel();
          await catalogChanges.cancel();
        };
      });
    });
