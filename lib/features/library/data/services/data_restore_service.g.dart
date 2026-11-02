// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_restore_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(dataRestoreService)
final dataRestoreServiceProvider = DataRestoreServiceProvider._();

final class DataRestoreServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<DataRestoreService>,
          DataRestoreService,
          FutureOr<DataRestoreService>
        >
    with
        $FutureModifier<DataRestoreService>,
        $FutureProvider<DataRestoreService> {
  DataRestoreServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dataRestoreServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dataRestoreServiceHash();

  @$internal
  @override
  $FutureProviderElement<DataRestoreService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DataRestoreService> create(Ref ref) {
    return dataRestoreService(ref);
  }
}

String _$dataRestoreServiceHash() =>
    r'8b29ded3d7cd4a3ec366632c69e2127a149b1a99';
