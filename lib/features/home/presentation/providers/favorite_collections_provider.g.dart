// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_collections_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(favoriteCollections)
final favoriteCollectionsProvider = FavoriteCollectionsProvider._();

final class FavoriteCollectionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MediaCollection>>,
          List<MediaCollection>,
          Stream<List<MediaCollection>>
        >
    with
        $FutureModifier<List<MediaCollection>>,
        $StreamProvider<List<MediaCollection>> {
  FavoriteCollectionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoriteCollectionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoriteCollectionsHash();

  @$internal
  @override
  $StreamProviderElement<List<MediaCollection>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MediaCollection>> create(Ref ref) {
    return favoriteCollections(ref);
  }
}

String _$favoriteCollectionsHash() =>
    r'0272d6c1c34e7da29dbb10696df4c04ba8e78418';
