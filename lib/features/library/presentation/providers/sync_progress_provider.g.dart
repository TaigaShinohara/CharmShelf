// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_progress_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ライブラリ（内部・外部）の同期・インポート状態を管理するプロバイダー。

@ProviderFor(SyncProgressNotifier)
final syncProgressNotifierProvider = SyncProgressNotifierProvider._();

/// ライブラリ（内部・外部）の同期・インポート状態を管理するプロバイダー。
final class SyncProgressNotifierProvider
    extends $NotifierProvider<SyncProgressNotifier, SyncProgress> {
  /// ライブラリ（内部・外部）の同期・インポート状態を管理するプロバイダー。
  SyncProgressNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncProgressNotifierProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncProgressNotifierHash();

  @$internal
  @override
  SyncProgressNotifier create() => SyncProgressNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncProgress value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncProgress>(value),
    );
  }
}

String _$syncProgressNotifierHash() =>
    r'4de63ef4ca34e6ec4b1c5f6a1a8a69dd26c10207';

/// ライブラリ（内部・外部）の同期・インポート状態を管理するプロバイダー。

abstract class _$SyncProgressNotifier extends $Notifier<SyncProgress> {
  SyncProgress build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SyncProgress, SyncProgress>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncProgress, SyncProgress>,
              SyncProgress,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
