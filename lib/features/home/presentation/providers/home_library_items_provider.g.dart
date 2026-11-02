// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_library_items_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(homeLibraryItems)
final homeLibraryItemsProvider = HomeLibraryItemsProvider._();

final class HomeLibraryItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MediaItem>>,
          List<MediaItem>,
          Stream<List<MediaItem>>
        >
    with $FutureModifier<List<MediaItem>>, $StreamProvider<List<MediaItem>> {
  HomeLibraryItemsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeLibraryItemsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeLibraryItemsHash();

  @$internal
  @override
  $StreamProviderElement<List<MediaItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MediaItem>> create(Ref ref) {
    return homeLibraryItems(ref);
  }
}

String _$homeLibraryItemsHash() => r'5619c9f1537fcc88ddfe3cb216a7378acb82ab06';
