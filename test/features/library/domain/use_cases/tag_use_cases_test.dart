import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:private_shelf/core/error/app_error.dart';
import 'package:private_shelf/core/error/result.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/domain/models/tag.dart';
import 'package:private_shelf/features/library/domain/models/tag_facet.dart';
import 'package:private_shelf/features/library/domain/repositories/media_repository.dart';
import 'package:private_shelf/features/library/domain/repositories/tag_facet_repository.dart';
import 'package:private_shelf/features/library/domain/repositories/tag_repository.dart';
import 'package:private_shelf/features/library/application/use_cases/tag_use_cases.dart';

class FakeTagRepository implements TagRepository {
  final Map<int, Tag> _tags = {};
  int _nextId = 1;

  @override
  Future<Result<void, AppError>> save(Tag tag) async {
    if (tag.id == 0 || tag.id == Isar.autoIncrement) {
      tag.id = _nextId++;
    }
    _tags[tag.id] = tag;
    return Result.success(null);
  }

  @override
  Future<Result<void, AppError>> saveAll(List<Tag> tags) async {
    for (final tag in tags) {
      await save(tag);
    }
    return Result.success(null);
  }

  @override
  Future<Result<void, AppError>> saveTree(
    Tag tag,
    List<Tag> descendants,
  ) async {
    await save(tag);
    await saveAll(descendants);
    return Result.success(null);
  }

  @override
  Future<Result<Tag?, AppError>> getById(int id) async {
    return Result.success(_tags[id]);
  }

  @override
  Future<Result<Tag?, AppError>> getByKey(String key) async {
    for (final tag in _tags.values) {
      if (tag.key == key) return Result.success(tag);
    }
    return Result.success(null);
  }

  @override
  Future<Result<List<Tag>, AppError>> getAll() async {
    return Result.success(_tags.values.toList());
  }

  @override
  Stream<List<Tag>> watchTags() => Stream.value(_tags.values.toList());

  @override
  Future<Result<List<Tag>, AppError>> getByFacetId(int facetId) async {
    return Result.success(
      _tags.values.where((t) => t.facetId == facetId).toList(),
    );
  }

  @override
  Future<Result<List<Tag>, AppError>> getByFacetAndLevel(
    int facetId,
    int level,
  ) async {
    return Result.success(
      _tags.values
          .where((t) => t.facetId == facetId && t.level == level)
          .toList(),
    );
  }

  @override
  Future<Result<List<Tag>, AppError>> getChildren(int parentId) async {
    return Result.success(
      _tags.values.where((t) => t.parentId == parentId).toList(),
    );
  }

  @override
  Future<Result<void, AppError>> delete(int id) async {
    _tags.remove(id);
    return Result.success(null);
  }

  @override
  Future<Result<void, AppError>> recalculateUsageCounts() async {
    return Result.success(null);
  }
}

class FakeTagFacetRepository implements TagFacetRepository {
  FakeTagFacetRepository(this._tagRepository);

  final FakeTagRepository _tagRepository;
  final Map<int, TagFacet> _facets = {};
  int _nextId = 1;

  @override
  Future<Result<void, AppError>> save(TagFacet facet) async {
    if (facet.id == 0 || facet.id == Isar.autoIncrement) {
      facet.id = _nextId++;
    }
    _facets[facet.id] = facet;
    return Result.success(null);
  }

  @override
  Future<Result<void, AppError>> saveAll(List<TagFacet> facets) async {
    for (final facet in facets) {
      await save(facet);
    }
    return Result.success(null);
  }

  @override
  Future<Result<TagFacet?, AppError>> getById(int id) async {
    return Result.success(_facets[id]);
  }

  @override
  Future<Result<TagFacet?, AppError>> getByName(String name) async {
    for (final facet in _facets.values) {
      if (facet.name == name) return Result.success(facet);
    }
    return Result.success(null);
  }

  @override
  Future<Result<List<TagFacet>, AppError>> getAll() async {
    return Result.success(_facets.values.toList());
  }

  @override
  Stream<List<TagFacet>> watchFacets() => Stream.value(_facets.values.toList());

  @override
  Future<Result<void, AppError>> delete(int id) async {
    _facets.remove(id);
    return Result.success(null);
  }

  @override
  Future<Result<void, AppError>> deleteAndReassignTags(
    int id,
    TagFacet replacement,
  ) async {
    for (final tag in _tagRepository._tags.values.where(
      (tag) => tag.facetId == id,
    )) {
      tag
        ..facetId = replacement.id
        ..key = Tag.buildKey(replacement.id, tag.name);
    }
    _facets.remove(id);
    return Result.success(null);
  }
}

class FakeMediaRepository implements MediaRepository {
  @override
  Future<Result<List<MediaItem>, AppError>> getAll({
    MediaFilter? filter,
  }) async {
    return Result.success(<MediaItem>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeTagRepository tagRepo;
  late FakeTagFacetRepository facetRepo;
  late FakeMediaRepository mediaRepo;

  setUp(() {
    tagRepo = FakeTagRepository();
    facetRepo = FakeTagFacetRepository(tagRepo);
    mediaRepo = FakeMediaRepository();
  });

  group('TagFacetRepository saveAll', () {
    test('saves multiple facets correctly', () async {
      final facet1 = TagFacet()
        ..name = 'Facet 1'
        ..sortOrder = 0
        ..createdAt = DateTime.now();
      final facet2 = TagFacet()
        ..name = 'Facet 2'
        ..sortOrder = 1
        ..createdAt = DateTime.now();

      final result = await facetRepo.saveAll([facet1, facet2]);
      expect(result.isSuccess, isTrue);

      final allResult = await facetRepo.getAll();
      expect(allResult.isSuccess, isTrue);
      final all = (allResult as Success<List<TagFacet>, dynamic>).data;
      expect(all.length, 2);
      expect(all.map((f) => f.name).toSet(), {'Facet 1', 'Facet 2'});
    });
  });

  group('TagUseCases', () {
    test(
      'CreateTagUseCase creates root and child tag with ancestorIds',
      () async {
        final createUseCase = CreateTagUseCase(
          Future.value(tagRepo),
          Future.value(facetRepo),
        );

        final tagResult = await createUseCase.invoke('Anime');
        expect(tagResult.isSuccess, isTrue);
        final tag = (tagResult as Success<Tag, dynamic>).data;
        expect(tag.name, 'Anime');
        expect(tag.facetId, isNotNull);

        // Child tag
        final childResult = await createUseCase.invoke(
          'Action Anime',
          facetId: tag.facetId,
          parentId: tag.id,
        );
        expect(childResult.isSuccess, isTrue);
        final childTag = (childResult as Success<Tag, dynamic>).data;
        expect(childTag.parentId, tag.id);
        expect(childTag.ancestorIds, contains(tag.id));
      },
    );

    test('EnsureTagDefaultsUseCase backfills facetId and keys', () async {
      final tag = Tag()
        ..id = 1
        ..name = 'UncategorizedTag'
        ..key = ''
        ..createdAt = DateTime.now();
      await tagRepo.save(tag);

      final ensureUseCase = EnsureTagDefaultsUseCase(
        Future.value(tagRepo),
        Future.value(facetRepo),
      );

      final result = await ensureUseCase.invoke();
      expect(result.isSuccess, isTrue);

      final updated = (await tagRepo.getById(1) as Success<Tag?, dynamic>).data;
      expect(updated!.facetId, isNotNull);
      expect(updated.key, isNotEmpty);
    });

    test(
      'UpdateTagUseCase updates tag and recalculates descendant ancestorIds',
      () async {
        final createUseCase = CreateTagUseCase(
          Future.value(tagRepo),
          Future.value(facetRepo),
        );
        final updateUseCase = UpdateTagUseCase(
          Future.value(tagRepo),
          Future.value(facetRepo),
        );

        // Root A
        final rootARes = await createUseCase.invoke('RootA');
        final rootA = (rootARes as Success<Tag, dynamic>).data;

        // Root B
        final rootBRes = await createUseCase.invoke('RootB');
        final rootB = (rootBRes as Success<Tag, dynamic>).data;

        // Child 1 (Parent: Root A)
        final child1Res = await createUseCase.invoke(
          'Child1',
          facetId: rootA.facetId,
          parentId: rootA.id,
        );
        final child1 = (child1Res as Success<Tag, dynamic>).data;
        expect(child1.ancestorIds, [rootA.id]);

        // Grandchild 1 (Parent: Child 1)
        final grandchild1Res = await createUseCase.invoke(
          'Grandchild1',
          facetId: rootA.facetId,
          parentId: child1.id,
        );
        final grandchild1 = (grandchild1Res as Success<Tag, dynamic>).data;
        expect(grandchild1.ancestorIds, [child1.id, rootA.id]);

        // Move Child 1 from Root A to Root B
        final updateRes = await updateUseCase.invoke(
          child1,
          name: child1.name,
          facetId: rootB.facetId,
          parentId: rootB.id,
        );
        expect(updateRes.isSuccess, isTrue);

        // Verify Child 1 ancestors
        final updatedChild1 =
            (await tagRepo.getById(child1.id) as Success<Tag?, dynamic>).data!;
        expect(updatedChild1.parentId, rootB.id);
        expect(updatedChild1.ancestorIds, [rootB.id]);

        // Verify Grandchild 1 ancestors are recursively updated
        final updatedGrandchild1 =
            (await tagRepo.getById(grandchild1.id) as Success<Tag?, dynamic>)
                .data!;
        expect(updatedGrandchild1.ancestorIds, [child1.id, rootB.id]);
      },
    );

    test('UpdateTagUseCase detects circular relationship', () async {
      final createUseCase = CreateTagUseCase(
        Future.value(tagRepo),
        Future.value(facetRepo),
      );
      final updateUseCase = UpdateTagUseCase(
        Future.value(tagRepo),
        Future.value(facetRepo),
      );

      final tag1Res = await createUseCase.invoke('Tag1');
      final tag1 = (tag1Res as Success<Tag, dynamic>).data;

      final tag2Res = await createUseCase.invoke(
        'Tag2',
        facetId: tag1.facetId,
        parentId: tag1.id,
      );
      final tag2 = (tag2Res as Success<Tag, dynamic>).data;

      // Attempt to make Tag1's parent Tag2 (which is Tag1's child) -> Cycle!
      final cycleRes = await updateUseCase.invoke(
        tag1,
        name: tag1.name,
        parentId: tag2.id,
      );
      expect(cycleRes.isFailure, isTrue);
    });

    test('DeleteTagUseCase prevents deleting a tag with children', () async {
      final createUseCase = CreateTagUseCase(
        Future.value(tagRepo),
        Future.value(facetRepo),
      );
      final deleteUseCase = DeleteTagUseCase(
        Future.value(tagRepo),
        Future.value(facetRepo),
        Future.value(mediaRepo),
      );

      final parentRes = await createUseCase.invoke('ParentTag');
      final parent = (parentRes as Success<Tag, dynamic>).data;

      await createUseCase.invoke(
        'ChildTag',
        facetId: parent.facetId,
        parentId: parent.id,
      );

      final deleteRes = await deleteUseCase.invoke(parent.id);
      expect(deleteRes.isFailure, isTrue);
    });

    test(
      'DeleteTagFacetUseCase prevents deleting default facet and migrates tags',
      () async {
        final createFacetUseCase = CreateTagFacetUseCase(
          Future.value(facetRepo),
        );
        final deleteFacetUseCase = DeleteTagFacetUseCase(
          Future.value(facetRepo),
        );
        final createTagUseCase = CreateTagUseCase(
          Future.value(tagRepo),
          Future.value(facetRepo),
        );

        // Create a custom facet
        final customFacetRes = await createFacetUseCase.invoke('CustomFacet');
        expect(customFacetRes.isSuccess, isTrue);
        final customFacet = (customFacetRes as Success<TagFacet, dynamic>).data;

        // Create a tag under custom facet
        final tagRes = await createTagUseCase.invoke(
          'CustomTag',
          facetId: customFacet.id,
        );
        final tag = (tagRes as Success<Tag, dynamic>).data;
        expect(tag.facetId, customFacet.id);

        // Delete custom facet
        final deleteRes = await deleteFacetUseCase.invoke(customFacet.id);
        expect(deleteRes.isSuccess, isTrue);

        // Tag should now be under default '未分類' facet
        final updatedTag =
            (await tagRepo.getById(tag.id) as Success<Tag?, dynamic>).data!;
        final defaultFacet =
            (await facetRepo.getByName('未分類') as Success<TagFacet?, dynamic>)
                .data!;
        expect(updatedTag.facetId, defaultFacet.id);

        // Attempt to delete default facet -> Should fail
        final deleteDefaultRes = await deleteFacetUseCase.invoke(
          defaultFacet.id,
        );
        expect(deleteDefaultRes.isFailure, isTrue);
      },
    );
  });
}
