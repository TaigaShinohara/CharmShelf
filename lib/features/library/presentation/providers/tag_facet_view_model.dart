import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/data/repositories/tag_facet_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/application/use_cases/tag_use_cases.dart';

part 'tag_facet_view_model.g.dart';

@riverpod
class TagFacetListViewModel extends _$TagFacetListViewModel {
  @override
  Stream<List<TagFacet>> build() {
    return Stream.fromFuture(
      ref.watch(tagFacetRepositoryProvider.future),
    ).asyncExpand((repo) => repo.watchFacets());
  }

  Future<void> addFacet(String name, {int? colorValue, int? sortOrder}) async {
    final useCase = ref.read(createTagFacetUseCaseProvider);
    final result = await useCase.invoke(
      name,
      colorValue: colorValue,
      sortOrder: sortOrder,
    );
    if (result is Success) {
      ref.invalidateSelf();
    } else if (result is Failure<TagFacet, AppError>) {
      throw result.error;
    }
  }

  Future<void> updateFacet(
    TagFacet facet, {
    required String name,
    int? colorValue,
    int? sortOrder,
  }) async {
    final useCase = ref.read(updateTagFacetUseCaseProvider);
    final result = await useCase.invoke(
      facet,
      name: name,
      colorValue: colorValue,
      sortOrder: sortOrder,
    );
    if (result is Success) {
      ref.invalidateSelf();
    } else if (result is Failure<void, AppError>) {
      throw result.error;
    }
  }

  Future<void> deleteFacet(int id) async {
    final useCase = ref.read(deleteTagFacetUseCaseProvider);
    final result = await useCase.invoke(id);
    if (result is Success) {
      ref.invalidateSelf();
    } else if (result is Failure<void, AppError>) {
      throw result.error;
    }
  }

  Future<void> reorderFacets(List<TagFacet> ordered) async {
    final repo = await ref.read(tagFacetRepositoryProvider.future);
    for (var i = 0; i < ordered.length; i++) {
      ordered[i].sortOrder = i;
    }
    final result = await repo.saveAll(ordered);
    if (result is Failure<void, AppError>) {
      throw result.error;
    }
    ref.invalidateSelf();
  }
}
