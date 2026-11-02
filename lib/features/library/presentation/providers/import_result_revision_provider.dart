import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/features/library/domain/models/collection.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';

/// Invalidate visible result rows after metadata changes without loading the
/// entire library or generating thumbnails. Only on-screen rows resolve again.
final importResultRevisionProvider = StreamProvider.autoDispose<int>((
  ref,
) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* Stream<int>.multi((controller) {
    var revision = 0;
    final media = isar.mediaItems.watchLazy().listen(
      (_) => controller.add(++revision),
    );
    final catalogs = isar.mediaCollections.watchLazy().listen(
      (_) => controller.add(++revision),
    );
    controller.onCancel = () async {
      await media.cancel();
      await catalogs.cancel();
    };
  });
});
