// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'move_media_item_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(moveMediaItemUseCase)
final moveMediaItemUseCaseProvider = MoveMediaItemUseCaseProvider._();

final class MoveMediaItemUseCaseProvider
    extends
        $FunctionalProvider<
          MoveMediaItemUseCase,
          MoveMediaItemUseCase,
          MoveMediaItemUseCase
        >
    with $Provider<MoveMediaItemUseCase> {
  MoveMediaItemUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'moveMediaItemUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$moveMediaItemUseCaseHash();

  @$internal
  @override
  $ProviderElement<MoveMediaItemUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MoveMediaItemUseCase create(Ref ref) {
    return moveMediaItemUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MoveMediaItemUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MoveMediaItemUseCase>(value),
    );
  }
}

String _$moveMediaItemUseCaseHash() =>
    r'3f86a9559958994e209c34a070f6130bf3ba67f7';
