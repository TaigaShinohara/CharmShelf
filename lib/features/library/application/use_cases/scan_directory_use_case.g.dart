// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_directory_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(scanDirectoryUseCase)
final scanDirectoryUseCaseProvider = ScanDirectoryUseCaseProvider._();

final class ScanDirectoryUseCaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<ScanDirectoryUseCase>,
          ScanDirectoryUseCase,
          FutureOr<ScanDirectoryUseCase>
        >
    with
        $FutureModifier<ScanDirectoryUseCase>,
        $FutureProvider<ScanDirectoryUseCase> {
  ScanDirectoryUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scanDirectoryUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scanDirectoryUseCaseHash();

  @$internal
  @override
  $FutureProviderElement<ScanDirectoryUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ScanDirectoryUseCase> create(Ref ref) {
    return scanDirectoryUseCase(ref);
  }
}

String _$scanDirectoryUseCaseHash() =>
    r'53083c89dd1e603b29127df8a6c065be84afe5ad';
