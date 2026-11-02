// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'internal_import_service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(internalImportService)
final internalImportServiceProvider = InternalImportServiceProvider._();

final class InternalImportServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<InternalImportService>,
          InternalImportService,
          FutureOr<InternalImportService>
        >
    with
        $FutureModifier<InternalImportService>,
        $FutureProvider<InternalImportService> {
  InternalImportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'internalImportServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$internalImportServiceHash();

  @$internal
  @override
  $FutureProviderElement<InternalImportService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InternalImportService> create(Ref ref) {
    return internalImportService(ref);
  }
}

String _$internalImportServiceHash() =>
    r'c661cb2ce27764d45fff4a46c031dec170497417';

@ProviderFor(advancedImportUseCase)
final advancedImportUseCaseProvider = AdvancedImportUseCaseProvider._();

final class AdvancedImportUseCaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<AdvancedImportUseCase>,
          AdvancedImportUseCase,
          FutureOr<AdvancedImportUseCase>
        >
    with
        $FutureModifier<AdvancedImportUseCase>,
        $FutureProvider<AdvancedImportUseCase> {
  AdvancedImportUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'advancedImportUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$advancedImportUseCaseHash();

  @$internal
  @override
  $FutureProviderElement<AdvancedImportUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AdvancedImportUseCase> create(Ref ref) {
    return advancedImportUseCase(ref);
  }
}

String _$advancedImportUseCaseHash() =>
    r'dc16a56b38a4f7d6249c8db40dcb5e5241bd8bd6';
