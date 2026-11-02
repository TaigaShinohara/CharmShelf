// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'security_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(securityRepositoryImpl)
final securityRepositoryImplProvider = SecurityRepositoryImplProvider._();

final class SecurityRepositoryImplProvider
    extends
        $FunctionalProvider<
          SecurityRepository,
          SecurityRepository,
          SecurityRepository
        >
    with $Provider<SecurityRepository> {
  SecurityRepositoryImplProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'securityRepositoryImplProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$securityRepositoryImplHash();

  @$internal
  @override
  $ProviderElement<SecurityRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SecurityRepository create(Ref ref) {
    return securityRepositoryImpl(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecurityRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecurityRepository>(value),
    );
  }
}

String _$securityRepositoryImplHash() =>
    r'dc07dbffe1b73d0d7b986dea21b295e655c8611d';
