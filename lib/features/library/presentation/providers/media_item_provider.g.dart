// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_item_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mediaItem)
final mediaItemProvider = MediaItemFamily._();

final class MediaItemProvider
    extends
        $FunctionalProvider<
          AsyncValue<MediaItem?>,
          MediaItem?,
          FutureOr<MediaItem?>
        >
    with $FutureModifier<MediaItem?>, $FutureProvider<MediaItem?> {
  MediaItemProvider._({
    required MediaItemFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'mediaItemProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaItemHash();

  @override
  String toString() {
    return r'mediaItemProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MediaItem?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<MediaItem?> create(Ref ref) {
    final argument = this.argument as int;
    return mediaItem(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MediaItemProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaItemHash() => r'01ba2593a75bd611b13b9dc8f7da935758274828';

final class MediaItemFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MediaItem?>, int> {
  MediaItemFamily._()
    : super(
        retry: null,
        name: r'mediaItemProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MediaItemProvider call(int id) =>
      MediaItemProvider._(argument: id, from: this);

  @override
  String toString() => r'mediaItemProvider';
}
