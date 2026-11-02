// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'export_media_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(exportMediaUseCase)
final exportMediaUseCaseProvider = ExportMediaUseCaseProvider._();

final class ExportMediaUseCaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<ExportMediaUseCase>,
          ExportMediaUseCase,
          FutureOr<ExportMediaUseCase>
        >
    with
        $FutureModifier<ExportMediaUseCase>,
        $FutureProvider<ExportMediaUseCase> {
  ExportMediaUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exportMediaUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exportMediaUseCaseHash();

  @$internal
  @override
  $FutureProviderElement<ExportMediaUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ExportMediaUseCase> create(Ref ref) {
    return exportMediaUseCase(ref);
  }
}

String _$exportMediaUseCaseHash() =>
    r'1ed85e9030bbe93d2760fec5c2360389faa30baf';
