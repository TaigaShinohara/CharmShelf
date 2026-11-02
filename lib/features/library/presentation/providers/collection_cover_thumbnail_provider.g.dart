// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_cover_thumbnail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// カタログのカバー画像（サムネイル）を多段階で解決するプロバイダー

@ProviderFor(collectionCoverThumbnail)
final collectionCoverThumbnailProvider = CollectionCoverThumbnailFamily._();

/// カタログのカバー画像（サムネイル）を多段階で解決するプロバイダー

final class CollectionCoverThumbnailProvider
    extends
        $FunctionalProvider<
          AsyncValue<CollectionCoverData?>,
          CollectionCoverData?,
          FutureOr<CollectionCoverData?>
        >
    with
        $FutureModifier<CollectionCoverData?>,
        $FutureProvider<CollectionCoverData?> {
  /// カタログのカバー画像（サムネイル）を多段階で解決するプロバイダー
  CollectionCoverThumbnailProvider._({
    required CollectionCoverThumbnailFamily super.from,
    required MediaCollection super.argument,
  }) : super(
         retry: null,
         name: r'collectionCoverThumbnailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$collectionCoverThumbnailHash();

  @override
  String toString() {
    return r'collectionCoverThumbnailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CollectionCoverData?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CollectionCoverData?> create(Ref ref) {
    final argument = this.argument as MediaCollection;
    return collectionCoverThumbnail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CollectionCoverThumbnailProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$collectionCoverThumbnailHash() =>
    r'450d1bfd6493e02af3c563730664f98ee9ff2ad1';

/// カタログのカバー画像（サムネイル）を多段階で解決するプロバイダー

final class CollectionCoverThumbnailFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<CollectionCoverData?>,
          MediaCollection
        > {
  CollectionCoverThumbnailFamily._()
    : super(
        retry: null,
        name: r'collectionCoverThumbnailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// カタログのカバー画像（サムネイル）を多段階で解決するプロバイダー

  CollectionCoverThumbnailProvider call(MediaCollection collection) =>
      CollectionCoverThumbnailProvider._(argument: collection, from: this);

  @override
  String toString() => r'collectionCoverThumbnailProvider';
}
