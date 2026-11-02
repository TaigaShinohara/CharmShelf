import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/features/library/data/services/tag_preset_service.dart';

part 'tag_preset_provider.g.dart';

@riverpod
Future<TagPresetService> tagPresetService(Ref ref) async {
  final isar = await ref.watch(isarProvider.future);
  return TagPresetService(isar);
}
