// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toggle_hidden_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(toggleHiddenUseCase)
final toggleHiddenUseCaseProvider = ToggleHiddenUseCaseProvider._();

final class ToggleHiddenUseCaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<ToggleHiddenUseCase>,
          ToggleHiddenUseCase,
          FutureOr<ToggleHiddenUseCase>
        >
    with
        $FutureModifier<ToggleHiddenUseCase>,
        $FutureProvider<ToggleHiddenUseCase> {
  ToggleHiddenUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toggleHiddenUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toggleHiddenUseCaseHash();

  @$internal
  @override
  $FutureProviderElement<ToggleHiddenUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ToggleHiddenUseCase> create(Ref ref) {
    return toggleHiddenUseCase(ref);
  }
}

String _$toggleHiddenUseCaseHash() =>
    r'463ea98e4aba0cb7524dce268318a0dc74419b73';
