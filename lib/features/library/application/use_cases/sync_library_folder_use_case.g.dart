// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_library_folder_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(syncLibraryFolderUseCase)
final syncLibraryFolderUseCaseProvider = SyncLibraryFolderUseCaseProvider._();

final class SyncLibraryFolderUseCaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncLibraryFolderUseCase>,
          SyncLibraryFolderUseCase,
          FutureOr<SyncLibraryFolderUseCase>
        >
    with
        $FutureModifier<SyncLibraryFolderUseCase>,
        $FutureProvider<SyncLibraryFolderUseCase> {
  SyncLibraryFolderUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncLibraryFolderUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncLibraryFolderUseCaseHash();

  @$internal
  @override
  $FutureProviderElement<SyncLibraryFolderUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SyncLibraryFolderUseCase> create(Ref ref) {
    return syncLibraryFolderUseCase(ref);
  }
}

String _$syncLibraryFolderUseCaseHash() =>
    r'10f42441c116fea86d6a78f30e9620ee60ccd02e';
