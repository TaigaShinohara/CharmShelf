import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/application/use_cases/tag_use_cases.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/features/library/data/repositories/tag_repository_provider.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';

part 'tag_view_model.g.dart';

@riverpod
class TagListViewModel extends _$TagListViewModel {
  @override
  Stream<List<Tag>> build() {
    return Stream.fromFuture(
      ref.watch(tagRepositoryProvider.future),
    ).asyncExpand((repo) => repo.watchTags());
  }

  Future<Tag> addTag(
    String name, {
    int? facetId,
    int? parentId,
    int? level,
    int? colorValue,
    bool isHidden = false,
  }) async {
    final useCase = ref.read(createTagUseCaseProvider);
    final result = await useCase.invoke(
      name,
      facetId: facetId,
      parentId: parentId,
      level: level,
      colorValue: colorValue,
      isHidden: isHidden,
    );
    if (result is Success<Tag, AppError>) {
      ref.invalidateSelf();
      return result.data;
    }
    throw (result as Failure<Tag, AppError>).error;
  }

  Future<void> updateTag(
    Tag tag, {
    required String name,
    int? facetId,
    int? parentId,
    int? level,
    int? colorValue,
    bool? isHidden,
  }) async {
    final useCase = ref.read(updateTagUseCaseProvider);
    final result = await useCase.invoke(
      tag,
      name: name,
      facetId: facetId,
      parentId: parentId,
      level: level,
      colorValue: colorValue,
      isHidden: isHidden,
    );
    if (result is Success) {
      ref.invalidateSelf();
    } else if (result is Failure<void, AppError>) {
      throw result.error;
    }
  }

  Future<void> deleteTag(int id) async {
    final useCase = ref.read(deleteTagUseCaseProvider);
    final result = await useCase.invoke(id);
    if (result is Success) {
      ref.invalidateSelf();
    } else if (result is Failure<void, AppError>) {
      throw result.error;
    }
  }
}

@riverpod
AsyncValue<List<Tag>> visibleTagList(Ref ref) {
  final secretModeAsync = ref.watch(secretModeProvider);
  final tagsAsync = ref.watch(tagListViewModelProvider);

  // いずれかがロード中またはエラーの場合は、その状態をそのまま返すか、
  // dataがある場合のみフィルタリングを行う。
  return secretModeAsync.when(
    data: (isSecretMode) {
      return tagsAsync.whenData((tags) {
        if (isSecretMode) {
          return tags;
        } else {
          return tags.where((tag) => !tag.isHidden).toList();
        }
      });
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
}
