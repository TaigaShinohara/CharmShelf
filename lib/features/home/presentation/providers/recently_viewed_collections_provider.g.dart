// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recently_viewed_collections_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(recentlyViewedCollections)
final recentlyViewedCollectionsProvider = RecentlyViewedCollectionsProvider._();

final class RecentlyViewedCollectionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MediaCollection>>,
          List<MediaCollection>,
          Stream<List<MediaCollection>>
        >
    with
        $FutureModifier<List<MediaCollection>>,
        $StreamProvider<List<MediaCollection>> {
  RecentlyViewedCollectionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentlyViewedCollectionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentlyViewedCollectionsHash();

  @$internal
  @override
  $StreamProviderElement<List<MediaCollection>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MediaCollection>> create(Ref ref) {
    return recentlyViewedCollections(ref);
  }
}

String _$recentlyViewedCollectionsHash() =>
    r'20591eb67ab7c74ef113760156f1573999c375b7';
