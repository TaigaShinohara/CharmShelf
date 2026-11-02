// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_media_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(importMediaUseCase)
final importMediaUseCaseProvider = ImportMediaUseCaseProvider._();

final class ImportMediaUseCaseProvider
    extends
        $FunctionalProvider<
          ImportMediaUseCase,
          ImportMediaUseCase,
          ImportMediaUseCase
        >
    with $Provider<ImportMediaUseCase> {
  ImportMediaUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'importMediaUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$importMediaUseCaseHash();

  @$internal
  @override
  $ProviderElement<ImportMediaUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ImportMediaUseCase create(Ref ref) {
    return importMediaUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportMediaUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportMediaUseCase>(value),
    );
  }
}

String _$importMediaUseCaseHash() =>
    r'3e5a50052b4c760f60809a641bc46e40a5730495';
