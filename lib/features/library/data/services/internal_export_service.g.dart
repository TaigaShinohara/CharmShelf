// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'internal_export_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(internalExportService)
final internalExportServiceProvider = InternalExportServiceProvider._();

final class InternalExportServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<InternalExportService>,
          InternalExportService,
          FutureOr<InternalExportService>
        >
    with
        $FutureModifier<InternalExportService>,
        $FutureProvider<InternalExportService> {
  InternalExportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'internalExportServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$internalExportServiceHash();

  @$internal
  @override
  $FutureProviderElement<InternalExportService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InternalExportService> create(Ref ref) {
    return internalExportService(ref);
  }
}

String _$internalExportServiceHash() =>
    r'bbe81a2ba245045652374168a204e043dbb911d9';
