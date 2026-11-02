// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'folder_sync_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FolderSyncNotifier)
final folderSyncNotifierProvider = FolderSyncNotifierProvider._();

final class FolderSyncNotifierProvider
    extends $NotifierProvider<FolderSyncNotifier, SyncProgress> {
  FolderSyncNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'folderSyncNotifierProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$folderSyncNotifierHash();

  @$internal
  @override
  FolderSyncNotifier create() => FolderSyncNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncProgress value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncProgress>(value),
    );
  }
}

String _$folderSyncNotifierHash() =>
    r'e4e6f52df15215c6e3dc0962a1d979d1015d4412';

abstract class _$FolderSyncNotifier extends $Notifier<SyncProgress> {
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
