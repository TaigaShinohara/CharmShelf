// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_media_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(updateMediaUseCase)
final updateMediaUseCaseProvider = UpdateMediaUseCaseProvider._();

final class UpdateMediaUseCaseProvider
    extends
        $FunctionalProvider<
          UpdateMediaUseCase,
          UpdateMediaUseCase,
          UpdateMediaUseCase
        >
    with $Provider<UpdateMediaUseCase> {
  UpdateMediaUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateMediaUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateMediaUseCaseHash();

  @$internal
  @override
  $ProviderElement<UpdateMediaUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UpdateMediaUseCase create(Ref ref) {
    return updateMediaUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateMediaUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateMediaUseCase>(value),
    );
  }
}

String _$updateMediaUseCaseHash() =>
    r'b3106caaa5c535c5a5f4e96aa68f2bb98ce9e912';
