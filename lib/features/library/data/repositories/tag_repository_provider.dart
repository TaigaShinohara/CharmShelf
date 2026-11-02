import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/features/library/data/repositories/isar_tag_repository.dart';
import 'package:private_shelf/features/library/domain/repositories/tag_repository.dart';

part 'tag_repository_provider.g.dart';

@Riverpod(keepAlive: true)
Future<TagRepository> tagRepository(Ref ref) async {
  final isar = await ref.watch(isarProvider.future);
  return IsarTagRepository(isar);
}
