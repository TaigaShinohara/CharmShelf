// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snackbar_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// SnackBar設定の状態管理

@ProviderFor(SnackBarConfigNotifier)
final snackBarConfigNotifierProvider = SnackBarConfigNotifierProvider._();

/// SnackBar設定の状態管理
final class SnackBarConfigNotifierProvider
    extends $NotifierProvider<SnackBarConfigNotifier, SnackBarConfig> {
  /// SnackBar設定の状態管理
  SnackBarConfigNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'snackBarConfigNotifierProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$snackBarConfigNotifierHash();

  @$internal
  @override
  SnackBarConfigNotifier create() => SnackBarConfigNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SnackBarConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SnackBarConfig>(value),
    );
  }
}

String _$snackBarConfigNotifierHash() =>
    r'83f62412435086a5b029a6827a7988b1f47c12b2';

/// SnackBar設定の状態管理

abstract class _$SnackBarConfigNotifier extends $Notifier<SnackBarConfig> {
  SnackBarConfig build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SnackBarConfig, SnackBarConfig>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SnackBarConfig, SnackBarConfig>,
              SnackBarConfig,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
