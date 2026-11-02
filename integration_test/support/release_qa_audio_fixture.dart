import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:private_shelf/features/library/application/use_cases/import_media_use_case.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';

/// Called only after each smoke test has verified its isolated QA package.
/// Samples are previews, so native audio QA must explicitly import a fixture.
Future<MediaItem> importReleaseQaAudioFixture(
  ProviderContainer container,
) async {
  final temporary = await getTemporaryDirectory();
  final directory = await temporary.createTemp('release-qa-audio-');
  try {
    const name = 'suki_ga_totonou_tagshelf_pv.mp3';
    final bytes = await rootBundle.load('assets/sounds/$name');
    final source = File(p.join(directory.path, name));
    await source.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    final result = await container
        .read(importMediaUseCaseProvider)
        .invoke(source);
    if (result.isFailure) {
      throw StateError('QA audio fixture import failed: ${result.errorOrNull}');
    }
    return result.dataOrNull!;
  } finally {
    await directory.delete(recursive: true);
  }
}
