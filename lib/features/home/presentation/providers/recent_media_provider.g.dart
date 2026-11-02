// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_media_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(recentMedia)
final recentMediaProvider = RecentMediaProvider._();

final class RecentMediaProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MediaItem>>,
          List<MediaItem>,
          Stream<List<MediaItem>>
        >
    with $FutureModifier<List<MediaItem>>, $StreamProvider<List<MediaItem>> {
  RecentMediaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentMediaProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentMediaHash();

  @$internal
  @override
  $StreamProviderElement<List<MediaItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MediaItem>> create(Ref ref) {
    return recentMedia(ref);
  }
}

String _$recentMediaHash() => r'6c19361ada4750bbdcf246cd37f885a47c9a24e1';
