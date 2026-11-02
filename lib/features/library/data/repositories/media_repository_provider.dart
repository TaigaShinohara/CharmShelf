import 'dart:io';
import '../../../device_files/data/device_file_repository.dart';
import '../../../device_files/data/device_storage.dart';
import '../../domain/models/legacy_import_labels.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/features/library/data/repositories/isar_media_repository.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';

part 'media_repository_provider.g.dart';

@Riverpod(keepAlive: true)
Future<MediaRepository> mediaRepository(Ref ref) async {
  final isar = await ref.watch(isarProvider.future);
  return IsarMediaRepository(
    isar,
    legacyLabels: (path) async {
      if (!Platform.isAndroid) return null;
      final uri = Uri.tryParse(path);
      if (uri?.hasScheme == true && uri!.scheme != 'file') return null;
      final source = uri?.hasScheme == true ? uri! : Uri.file(path);
      final repository = await ref.read(deviceFileRepositoryProvider.future);
      if (!repository.hasSavedLabels(source)) return null;
      final actual = await ref.read(deviceStorageProvider).stat(source);
      final labels = repository.labels(actual);
      if (labels.tags.isEmpty && labels.catalog.isEmpty && !labels.favorite) {
        return null;
      }
      return LegacyImportLabels(
        tags: labels.tags,
        catalog: labels.catalog,
        favorite: labels.favorite,
      );
    },
  );
}
