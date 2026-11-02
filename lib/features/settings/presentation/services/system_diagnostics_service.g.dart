// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_diagnostics_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SystemDiagnosticsService)
final systemDiagnosticsServiceProvider = SystemDiagnosticsServiceProvider._();

final class SystemDiagnosticsServiceProvider
    extends $NotifierProvider<SystemDiagnosticsService, void> {
  SystemDiagnosticsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemDiagnosticsServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemDiagnosticsServiceHash();

  @$internal
  @override
  SystemDiagnosticsService create() => SystemDiagnosticsService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$systemDiagnosticsServiceHash() =>
    r'0c8a81ef7a02eb7625f71093772189471e0a7dd0';

abstract class _$SystemDiagnosticsService extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
