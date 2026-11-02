// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'path_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(applicationDocumentsPath)
final applicationDocumentsPathProvider = ApplicationDocumentsPathProvider._();

final class ApplicationDocumentsPathProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  ApplicationDocumentsPathProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'applicationDocumentsPathProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$applicationDocumentsPathHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return applicationDocumentsPath(ref);
  }
}

String _$applicationDocumentsPathHash() =>
    r'74f732f220a3bfd4f7f778f98b769d339442b71f';

@ProviderFor(appDocumentsPathSync)
final appDocumentsPathSyncProvider = AppDocumentsPathSyncProvider._();

final class AppDocumentsPathSyncProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  AppDocumentsPathSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDocumentsPathSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDocumentsPathSyncHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return appDocumentsPathSync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$appDocumentsPathSyncHash() =>
    r'3802a0da75556590325a9feee6fa78c03d0cf65e';
