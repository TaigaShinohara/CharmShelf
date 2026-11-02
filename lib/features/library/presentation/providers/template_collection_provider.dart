import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/core/services/file_service.dart';
import 'package:private_shelf/features/library/data/services/template_collection_service.dart';

part 'template_collection_provider.g.dart';

@riverpod
Future<TemplateCollectionService> templateCollectionService(
  Ref ref,
) async {
  final isar = await ref.watch(isarProvider.future);
  final fileService = ref.watch(fileServiceProvider);
  return TemplateCollectionService(isar, fileService);
}
