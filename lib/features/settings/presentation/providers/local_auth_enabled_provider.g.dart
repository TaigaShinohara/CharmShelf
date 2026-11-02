// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_auth_enabled_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(localAuthEnabled)
final localAuthEnabledProvider = LocalAuthEnabledProvider._();

final class LocalAuthEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  LocalAuthEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localAuthEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localAuthEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return localAuthEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$localAuthEnabledHash() => r'ef0299c01d8c58ffb00a14948cc09cd6d62f090a';
