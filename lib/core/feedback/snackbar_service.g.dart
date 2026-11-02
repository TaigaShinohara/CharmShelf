// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snackbar_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(snackBarService)
final snackBarServiceProvider = SnackBarServiceProvider._();

final class SnackBarServiceProvider
    extends
        $FunctionalProvider<SnackBarService, SnackBarService, SnackBarService>
    with $Provider<SnackBarService> {
  SnackBarServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'snackBarServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$snackBarServiceHash();

  @$internal
  @override
  $ProviderElement<SnackBarService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SnackBarService create(Ref ref) {
    return snackBarService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SnackBarService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SnackBarService>(value),
    );
  }
}

String _$snackBarServiceHash() => r'd1c4580289c70432b2c9a069226452926f41cc31';
