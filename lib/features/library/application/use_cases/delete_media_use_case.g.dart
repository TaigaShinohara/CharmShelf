// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_media_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deleteMediaUseCase)
final deleteMediaUseCaseProvider = DeleteMediaUseCaseProvider._();

final class DeleteMediaUseCaseProvider
    extends
        $FunctionalProvider<
          DeleteMediaUseCase,
          DeleteMediaUseCase,
          DeleteMediaUseCase
        >
    with $Provider<DeleteMediaUseCase> {
  DeleteMediaUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deleteMediaUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deleteMediaUseCaseHash();

  @$internal
  @override
  $ProviderElement<DeleteMediaUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DeleteMediaUseCase create(Ref ref) {
    return deleteMediaUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeleteMediaUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeleteMediaUseCase>(value),
    );
  }
}

String _$deleteMediaUseCaseHash() =>
    r'38c199a5866832295e769b38742080194d8772d3';
