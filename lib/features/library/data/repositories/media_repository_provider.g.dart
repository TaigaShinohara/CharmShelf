// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mediaRepository)
final mediaRepositoryProvider = MediaRepositoryProvider._();

final class MediaRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<MediaRepository>,
          MediaRepository,
          FutureOr<MediaRepository>
        >
    with $FutureModifier<MediaRepository>, $FutureProvider<MediaRepository> {
  MediaRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<MediaRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MediaRepository> create(Ref ref) {
    return mediaRepository(ref);
  }
}

String _$mediaRepositoryHash() => r'e267469285e415d3267217815825094d3dd1ee70';
