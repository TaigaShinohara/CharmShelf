// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permanently_delete_trashed_media_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(permanentlyDeleteTrashedMediaUseCase)
final permanentlyDeleteTrashedMediaUseCaseProvider =
    PermanentlyDeleteTrashedMediaUseCaseProvider._();

final class PermanentlyDeleteTrashedMediaUseCaseProvider
    extends
        $FunctionalProvider<
          PermanentlyDeleteTrashedMediaUseCase,
          PermanentlyDeleteTrashedMediaUseCase,
          PermanentlyDeleteTrashedMediaUseCase
        >
    with $Provider<PermanentlyDeleteTrashedMediaUseCase> {
  PermanentlyDeleteTrashedMediaUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'permanentlyDeleteTrashedMediaUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$permanentlyDeleteTrashedMediaUseCaseHash();

  @$internal
  @override
  $ProviderElement<PermanentlyDeleteTrashedMediaUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PermanentlyDeleteTrashedMediaUseCase create(Ref ref) {
    return permanentlyDeleteTrashedMediaUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PermanentlyDeleteTrashedMediaUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<PermanentlyDeleteTrashedMediaUseCase>(value),
    );
  }
}

String _$permanentlyDeleteTrashedMediaUseCaseHash() =>
    r'69f0a5a492eb0b21fdd1aebb5a9ae4fe34cfcb1e';
