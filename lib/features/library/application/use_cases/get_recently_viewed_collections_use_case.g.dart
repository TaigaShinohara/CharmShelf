// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_recently_viewed_collections_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(getRecentlyViewedCollectionsUseCase)
final getRecentlyViewedCollectionsUseCaseProvider =
    GetRecentlyViewedCollectionsUseCaseProvider._();

final class GetRecentlyViewedCollectionsUseCaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<GetRecentlyViewedCollectionsUseCase>,
          GetRecentlyViewedCollectionsUseCase,
          FutureOr<GetRecentlyViewedCollectionsUseCase>
        >
    with
        $FutureModifier<GetRecentlyViewedCollectionsUseCase>,
        $FutureProvider<GetRecentlyViewedCollectionsUseCase> {
  GetRecentlyViewedCollectionsUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getRecentlyViewedCollectionsUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$getRecentlyViewedCollectionsUseCaseHash();

  @$internal
  @override
  $FutureProviderElement<GetRecentlyViewedCollectionsUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GetRecentlyViewedCollectionsUseCase> create(Ref ref) {
    return getRecentlyViewedCollectionsUseCase(ref);
  }
}

String _$getRecentlyViewedCollectionsUseCaseHash() =>
    r'c02a435ebe5cd791a6602ca3a05de6f31c5d1cc1';
