// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'security_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(securityRepository)
final securityRepositoryProvider = SecurityRepositoryProvider._();

final class SecurityRepositoryProvider
    extends
        $FunctionalProvider<
          SecurityRepository,
          SecurityRepository,
          SecurityRepository
        >
    with $Provider<SecurityRepository> {
  SecurityRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'securityRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$securityRepositoryHash();

  @$internal
  @override
  $ProviderElement<SecurityRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SecurityRepository create(Ref ref) {
    return securityRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecurityRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecurityRepository>(value),
    );
  }
}

String _$securityRepositoryHash() =>
    r'7ccf2562578a7b82503d4d64f2488e06dcc85614';
