// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_facet_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tagFacetRepository)
final tagFacetRepositoryProvider = TagFacetRepositoryProvider._();

final class TagFacetRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<TagFacetRepository>,
          TagFacetRepository,
          FutureOr<TagFacetRepository>
        >
    with
        $FutureModifier<TagFacetRepository>,
        $FutureProvider<TagFacetRepository> {
  TagFacetRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tagFacetRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tagFacetRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<TagFacetRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TagFacetRepository> create(Ref ref) {
    return tagFacetRepository(ref);
  }
}

String _$tagFacetRepositoryHash() =>
    r'42ff13812eceaaa7132ada87f3a41be32d12da07';
