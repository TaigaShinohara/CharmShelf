// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_facet_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TagFacetListViewModel)
final tagFacetListViewModelProvider = TagFacetListViewModelProvider._();

final class TagFacetListViewModelProvider
    extends $StreamNotifierProvider<TagFacetListViewModel, List<TagFacet>> {
  TagFacetListViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tagFacetListViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tagFacetListViewModelHash();

  @$internal
  @override
  TagFacetListViewModel create() => TagFacetListViewModel();
}

String _$tagFacetListViewModelHash() =>
    r'9206a4fe83aa0a57778f1600a20e3a69ec707c7e';

abstract class _$TagFacetListViewModel extends $StreamNotifier<List<TagFacet>> {
  Stream<List<TagFacet>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<TagFacet>>, List<TagFacet>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<TagFacet>>, List<TagFacet>>,
              AsyncValue<List<TagFacet>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
