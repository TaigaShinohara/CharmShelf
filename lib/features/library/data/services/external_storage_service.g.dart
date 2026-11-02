// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'external_storage_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(externalStorageService)
final externalStorageServiceProvider = ExternalStorageServiceProvider._();

final class ExternalStorageServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<ExternalStorageService>,
          ExternalStorageService,
          FutureOr<ExternalStorageService>
        >
    with
        $FutureModifier<ExternalStorageService>,
        $FutureProvider<ExternalStorageService> {
  ExternalStorageServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'externalStorageServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$externalStorageServiceHash();

  @$internal
  @override
  $FutureProviderElement<ExternalStorageService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ExternalStorageService> create(Ref ref) {
    return externalStorageService(ref);
  }
}

String _$externalStorageServiceHash() =>
    r'5d9e4e90429e29edbed3c43a3ee17309c4b3daa6';
