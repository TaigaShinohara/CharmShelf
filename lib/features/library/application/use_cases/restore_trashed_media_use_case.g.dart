// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restore_trashed_media_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(restoreTrashedMediaUseCase)
final restoreTrashedMediaUseCaseProvider =
    RestoreTrashedMediaUseCaseProvider._();

final class RestoreTrashedMediaUseCaseProvider
    extends
        $FunctionalProvider<
          RestoreTrashedMediaUseCase,
          RestoreTrashedMediaUseCase,
          RestoreTrashedMediaUseCase
        >
    with $Provider<RestoreTrashedMediaUseCase> {
  RestoreTrashedMediaUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'restoreTrashedMediaUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$restoreTrashedMediaUseCaseHash();

  @$internal
  @override
  $ProviderElement<RestoreTrashedMediaUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RestoreTrashedMediaUseCase create(Ref ref) {
    return restoreTrashedMediaUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RestoreTrashedMediaUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RestoreTrashedMediaUseCase>(value),
    );
  }
}

String _$restoreTrashedMediaUseCaseHash() =>
    r'e3741d62f9e282b0554c4951390ba3a89ec357fc';
