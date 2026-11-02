// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sidecar_metadata_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sidecarMetadataService)
final sidecarMetadataServiceProvider = SidecarMetadataServiceProvider._();

final class SidecarMetadataServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<SidecarMetadataService>,
          SidecarMetadataService,
          FutureOr<SidecarMetadataService>
        >
    with
        $FutureModifier<SidecarMetadataService>,
        $FutureProvider<SidecarMetadataService> {
  SidecarMetadataServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sidecarMetadataServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sidecarMetadataServiceHash();

  @$internal
  @override
  $FutureProviderElement<SidecarMetadataService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SidecarMetadataService> create(Ref ref) {
    return sidecarMetadataService(ref);
  }
}

String _$sidecarMetadataServiceHash() =>
    r'4caadec6e4e7eeb68d5d46c1da5a0c605ba31aab';
