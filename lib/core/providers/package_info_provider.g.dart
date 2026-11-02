// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'package_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(packageInfo)
final packageInfoProvider = PackageInfoProvider._();

final class PackageInfoProvider
    extends
        $FunctionalProvider<
          AsyncValue<PackageInfo>,
          PackageInfo,
          FutureOr<PackageInfo>
        >
    with $FutureModifier<PackageInfo>, $FutureProvider<PackageInfo> {
  PackageInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'packageInfoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$packageInfoHash();

  @$internal
  @override
  $FutureProviderElement<PackageInfo> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PackageInfo> create(Ref ref) {
    return packageInfo(ref);
  }
}

String _$packageInfoHash() => r'907ba5b02ed285ba1e951e58a932554b0a8da650';

@ProviderFor(appVersion)
final appVersionProvider = AppVersionProvider._();

final class AppVersionProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  AppVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appVersionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appVersionHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return appVersion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$appVersionHash() => r'ecab31474805c7b82e1682c53f127ef4f027d7c7';

@ProviderFor(buildNumber)
final buildNumberProvider = BuildNumberProvider._();

final class BuildNumberProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  BuildNumberProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'buildNumberProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$buildNumberHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return buildNumber(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$buildNumberHash() => r'3c0134eb0366afe5a8fd41281526a523d1cf3770';

@ProviderFor(appName)
final appNameProvider = AppNameProvider._();

final class AppNameProvider extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  AppNameProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appNameProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appNameHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return appName(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$appNameHash() => r'8067d0345cd4770d688174cc58e1a2d066a79571';
