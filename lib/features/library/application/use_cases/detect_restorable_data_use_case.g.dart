// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'detect_restorable_data_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(detectRestorableDataUseCase)
final detectRestorableDataUseCaseProvider =
    DetectRestorableDataUseCaseProvider._();

final class DetectRestorableDataUseCaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<DetectRestorableDataUseCase>,
          DetectRestorableDataUseCase,
          FutureOr<DetectRestorableDataUseCase>
        >
    with
        $FutureModifier<DetectRestorableDataUseCase>,
        $FutureProvider<DetectRestorableDataUseCase> {
  DetectRestorableDataUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'detectRestorableDataUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$detectRestorableDataUseCaseHash();

  @$internal
  @override
  $FutureProviderElement<DetectRestorableDataUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DetectRestorableDataUseCase> create(Ref ref) {
    return detectRestorableDataUseCase(ref);
  }
}

String _$detectRestorableDataUseCaseHash() =>
    r'9d2f73bf95d7fe207112a053d2b2eeb3f7282faa';
