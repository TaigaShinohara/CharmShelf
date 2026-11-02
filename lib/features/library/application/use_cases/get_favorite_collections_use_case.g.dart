// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_favorite_collections_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(getFavoriteCollectionsUseCase)
final getFavoriteCollectionsUseCaseProvider =
    GetFavoriteCollectionsUseCaseProvider._();

final class GetFavoriteCollectionsUseCaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<GetFavoriteCollectionsUseCase>,
          GetFavoriteCollectionsUseCase,
          FutureOr<GetFavoriteCollectionsUseCase>
        >
    with
        $FutureModifier<GetFavoriteCollectionsUseCase>,
        $FutureProvider<GetFavoriteCollectionsUseCase> {
  GetFavoriteCollectionsUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getFavoriteCollectionsUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getFavoriteCollectionsUseCaseHash();

  @$internal
  @override
  $FutureProviderElement<GetFavoriteCollectionsUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GetFavoriteCollectionsUseCase> create(Ref ref) {
    return getFavoriteCollectionsUseCase(ref);
  }
}

String _$getFavoriteCollectionsUseCaseHash() =>
    r'a5f31489b4a1a73030dce092a55189e37fe7ce2b';
