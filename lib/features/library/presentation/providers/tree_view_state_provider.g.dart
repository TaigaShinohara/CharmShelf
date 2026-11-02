// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tree_view_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 展開されているフォルダパスの集合を管理するプロバイダー

@ProviderFor(ExpandedFoldersNotifier)
final expandedFoldersNotifierProvider = ExpandedFoldersNotifierProvider._();

/// 展開されているフォルダパスの集合を管理するプロバイダー
final class ExpandedFoldersNotifierProvider
    extends $NotifierProvider<ExpandedFoldersNotifier, Set<String>> {
  /// 展開されているフォルダパスの集合を管理するプロバイダー
  ExpandedFoldersNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'expandedFoldersNotifierProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$expandedFoldersNotifierHash();

  @$internal
  @override
  ExpandedFoldersNotifier create() => ExpandedFoldersNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$expandedFoldersNotifierHash() =>
    r'860f86e348b9d69ce1c78e5d63352560995b7a96';

/// 展開されているフォルダパスの集合を管理するプロバイダー

abstract class _$ExpandedFoldersNotifier extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 指定したフォルダパス配下の直下アイテム一覧を監視する。

@ProviderFor(folderChildren)
final folderChildrenProvider = FolderChildrenFamily._();

/// 指定したフォルダパス配下の直下アイテム一覧を監視する。

final class FolderChildrenProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MediaItem>>,
          List<MediaItem>,
          Stream<List<MediaItem>>
        >
    with $FutureModifier<List<MediaItem>>, $StreamProvider<List<MediaItem>> {
  /// 指定したフォルダパス配下の直下アイテム一覧を監視する。
  FolderChildrenProvider._({
    required FolderChildrenFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'folderChildrenProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$folderChildrenHash();

  @override
  String toString() {
    return r'folderChildrenProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<MediaItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<MediaItem>> create(Ref ref) {
    final argument = this.argument as String;
    return folderChildren(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FolderChildrenProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$folderChildrenHash() => r'bb8b50c216df9de7d098b3b4c7111660cfb74bab';

/// 指定したフォルダパス配下の直下アイテム一覧を監視する。

final class FolderChildrenFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<MediaItem>>, String> {
  FolderChildrenFamily._()
    : super(
        retry: null,
        name: r'folderChildrenProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 指定したフォルダパス配下の直下アイテム一覧を監視する。

  FolderChildrenProvider call(String folderPath) =>
      FolderChildrenProvider._(argument: folderPath, from: this);

  @override
  String toString() => r'folderChildrenProvider';
}

/// 展開中のフォルダを一つのリストに平坦化し、画面側で可視行だけを構築する。

@ProviderFor(treeMediaItems)
final treeMediaItemsProvider = TreeMediaItemsFamily._();

/// 展開中のフォルダを一つのリストに平坦化し、画面側で可視行だけを構築する。

final class TreeMediaItemsProvider
    extends
        $FunctionalProvider<
          List<TreeMediaItem>,
          List<TreeMediaItem>,
          List<TreeMediaItem>
        >
    with $Provider<List<TreeMediaItem>> {
  /// 展開中のフォルダを一つのリストに平坦化し、画面側で可視行だけを構築する。
  TreeMediaItemsProvider._({
    required TreeMediaItemsFamily super.from,
    required List<MediaItem> super.argument,
  }) : super(
         retry: null,
         name: r'treeMediaItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$treeMediaItemsHash();

  @override
  String toString() {
    return r'treeMediaItemsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<TreeMediaItem>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<TreeMediaItem> create(Ref ref) {
    final argument = this.argument as List<MediaItem>;
    return treeMediaItems(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TreeMediaItem> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<TreeMediaItem>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TreeMediaItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$treeMediaItemsHash() => r'875143df49f8e33004f61b980053482ea4070c78';

/// 展開中のフォルダを一つのリストに平坦化し、画面側で可視行だけを構築する。

final class TreeMediaItemsFamily extends $Family
    with $FunctionalFamilyOverride<List<TreeMediaItem>, List<MediaItem>> {
  TreeMediaItemsFamily._()
    : super(
        retry: null,
        name: r'treeMediaItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 展開中のフォルダを一つのリストに平坦化し、画面側で可視行だけを構築する。

  TreeMediaItemsProvider call(List<MediaItem> rootItems) =>
      TreeMediaItemsProvider._(argument: rootItems, from: this);

  @override
  String toString() => r'treeMediaItemsProvider';
}
