// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_clear_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(storageClearService)
final storageClearServiceProvider = StorageClearServiceProvider._();

final class StorageClearServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<StorageClearService>,
          StorageClearService,
          FutureOr<StorageClearService>
        >
    with
        $FutureModifier<StorageClearService>,
        $FutureProvider<StorageClearService> {
  StorageClearServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageClearServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageClearServiceHash();

  @$internal
  @override
  $FutureProviderElement<StorageClearService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<StorageClearService> create(Ref ref) {
    return storageClearService(ref);
  }
}

String _$storageClearServiceHash() =>
    r'955917b8a3ba2d2ec0274ea9c5307d0738b8f687';
