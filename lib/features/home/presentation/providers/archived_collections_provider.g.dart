// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archived_collections_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(archivedCollections)
final archivedCollectionsProvider = ArchivedCollectionsProvider._();

final class ArchivedCollectionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MediaCollection>>,
          List<MediaCollection>,
          FutureOr<List<MediaCollection>>
        >
    with
        $FutureModifier<List<MediaCollection>>,
        $FutureProvider<List<MediaCollection>> {
  ArchivedCollectionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'archivedCollectionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$archivedCollectionsHash();

  @$internal
  @override
  $FutureProviderElement<List<MediaCollection>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MediaCollection>> create(Ref ref) {
    return archivedCollections(ref);
  }
}

String _$archivedCollectionsHash() =>
    r'e46a9f81acc121ad853053f43918b15de42536f4';
