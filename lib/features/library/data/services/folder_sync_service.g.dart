// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'folder_sync_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(folderSyncService)
final folderSyncServiceProvider = FolderSyncServiceProvider._();

final class FolderSyncServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<FolderSyncService>,
          FolderSyncService,
          FutureOr<FolderSyncService>
        >
    with
        $FutureModifier<FolderSyncService>,
        $FutureProvider<FolderSyncService> {
  FolderSyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'folderSyncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$folderSyncServiceHash();

  @$internal
  @override
  $FutureProviderElement<FolderSyncService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FolderSyncService> create(Ref ref) {
    return folderSyncService(ref);
  }
}

String _$folderSyncServiceHash() => r'c6a15c6e19bf32c0a086d75a58e92730950712dc';
