// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trash_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(trashedMediaRoots)
final trashedMediaRootsProvider = TrashedMediaRootsProvider._();

final class TrashedMediaRootsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MediaItem>>,
          List<MediaItem>,
          FutureOr<List<MediaItem>>
        >
    with $FutureModifier<List<MediaItem>>, $FutureProvider<List<MediaItem>> {
  TrashedMediaRootsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trashedMediaRootsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trashedMediaRootsHash();

  @$internal
  @override
  $FutureProviderElement<List<MediaItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MediaItem>> create(Ref ref) {
    return trashedMediaRoots(ref);
  }
}

String _$trashedMediaRootsHash() => r'cd7b5d09a36e0193a5b53e7e720ffd1e1b11a1a7';
