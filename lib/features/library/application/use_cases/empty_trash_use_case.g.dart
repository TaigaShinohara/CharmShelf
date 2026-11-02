// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'empty_trash_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(emptyTrashUseCase)
final emptyTrashUseCaseProvider = EmptyTrashUseCaseProvider._();

final class EmptyTrashUseCaseProvider
    extends
        $FunctionalProvider<
          EmptyTrashUseCase,
          EmptyTrashUseCase,
          EmptyTrashUseCase
        >
    with $Provider<EmptyTrashUseCase> {
  EmptyTrashUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emptyTrashUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emptyTrashUseCaseHash();

  @$internal
  @override
  $ProviderElement<EmptyTrashUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EmptyTrashUseCase create(Ref ref) {
    return emptyTrashUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EmptyTrashUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EmptyTrashUseCase>(value),
    );
  }
}

String _$emptyTrashUseCaseHash() => r'e5f50c204012d6a2d5070e1ef37539d57284eccc';
