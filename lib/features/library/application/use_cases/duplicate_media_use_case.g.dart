// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'duplicate_media_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(duplicateMediaUseCase)
final duplicateMediaUseCaseProvider = DuplicateMediaUseCaseProvider._();

final class DuplicateMediaUseCaseProvider
    extends
        $FunctionalProvider<
          DuplicateMediaUseCase,
          DuplicateMediaUseCase,
          DuplicateMediaUseCase
        >
    with $Provider<DuplicateMediaUseCase> {
  DuplicateMediaUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'duplicateMediaUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$duplicateMediaUseCaseHash();

  @$internal
  @override
  $ProviderElement<DuplicateMediaUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DuplicateMediaUseCase create(Ref ref) {
    return duplicateMediaUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DuplicateMediaUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DuplicateMediaUseCase>(value),
    );
  }
}

String _$duplicateMediaUseCaseHash() =>
    r'53c4cba4666a38dbb186fad3005834b41fd608be';
