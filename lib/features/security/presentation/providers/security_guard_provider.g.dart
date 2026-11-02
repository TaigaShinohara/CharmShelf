// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'security_guard_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SecurityGuard)
final securityGuardProvider = SecurityGuardProvider._();

final class SecurityGuardProvider
    extends $AsyncNotifierProvider<SecurityGuard, bool> {
  SecurityGuardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'securityGuardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$securityGuardHash();

  @$internal
  @override
  SecurityGuard create() => SecurityGuard();
}

String _$securityGuardHash() => r'73aa5e395e5fa719caa3c8a6242bb6078181dc29';

abstract class _$SecurityGuard extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
