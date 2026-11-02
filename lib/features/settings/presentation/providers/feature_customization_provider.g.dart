// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_customization_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FolderManagementEnabledAsync)
final folderManagementEnabledAsyncProvider =
    FolderManagementEnabledAsyncProvider._();

final class FolderManagementEnabledAsyncProvider
    extends $AsyncNotifierProvider<FolderManagementEnabledAsync, bool> {
  FolderManagementEnabledAsyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'folderManagementEnabledAsyncProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$folderManagementEnabledAsyncHash();

  @$internal
  @override
  FolderManagementEnabledAsync create() => FolderManagementEnabledAsync();
}

String _$folderManagementEnabledAsyncHash() =>
    r'07600b9343d96733871da179a7d6359f944b8638';

abstract class _$FolderManagementEnabledAsync extends $AsyncNotifier<bool> {
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

@ProviderFor(folderManagementEnabled)
final folderManagementEnabledProvider = FolderManagementEnabledProvider._();

final class FolderManagementEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  FolderManagementEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'folderManagementEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$folderManagementEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return folderManagementEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$folderManagementEnabledHash() =>
    r'bbb26aa0711e4358673a66a697728c8fff2adba1';
