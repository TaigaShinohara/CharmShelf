// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'external_library_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 外部参照フォルダ一覧の状態管理プロバイダー。

@ProviderFor(ExternalFolderList)
final externalFolderListProvider = ExternalFolderListProvider._();

/// 外部参照フォルダ一覧の状態管理プロバイダー。
final class ExternalFolderListProvider
    extends $AsyncNotifierProvider<ExternalFolderList, List<MediaCollection>> {
  /// 外部参照フォルダ一覧の状態管理プロバイダー。
  ExternalFolderListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'externalFolderListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$externalFolderListHash();

  @$internal
  @override
  ExternalFolderList create() => ExternalFolderList();
}

String _$externalFolderListHash() =>
    r'060c7f11e50d424d05d54387e889ed7cf81a00b2';

/// 外部参照フォルダ一覧の状態管理プロバイダー。

abstract class _$ExternalFolderList
    extends $AsyncNotifier<List<MediaCollection>> {
  FutureOr<List<MediaCollection>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<MediaCollection>>, List<MediaCollection>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<MediaCollection>>,
                List<MediaCollection>
              >,
              AsyncValue<List<MediaCollection>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 特定の外部参照フォルダ内のファイル一覧プロバイダー。

@ProviderFor(ExternalFolderItems)
final externalFolderItemsProvider = ExternalFolderItemsFamily._();

/// 特定の外部参照フォルダ内のファイル一覧プロバイダー。
final class ExternalFolderItemsProvider
    extends $AsyncNotifierProvider<ExternalFolderItems, List<MediaItem>> {
  /// 特定の外部参照フォルダ内のファイル一覧プロバイダー。
  ExternalFolderItemsProvider._({
    required ExternalFolderItemsFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'externalFolderItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$externalFolderItemsHash();

  @override
  String toString() {
    return r'externalFolderItemsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ExternalFolderItems create() => ExternalFolderItems();

  @override
  bool operator ==(Object other) {
    return other is ExternalFolderItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$externalFolderItemsHash() =>
    r'257c0f916dec033475c2d17081b2145a12e0552d';

/// 特定の外部参照フォルダ内のファイル一覧プロバイダー。

final class ExternalFolderItemsFamily extends $Family
    with
        $ClassFamilyOverride<
          ExternalFolderItems,
          AsyncValue<List<MediaItem>>,
          List<MediaItem>,
          FutureOr<List<MediaItem>>,
          String?
        > {
  ExternalFolderItemsFamily._()
    : super(
        retry: null,
        name: r'externalFolderItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 特定の外部参照フォルダ内のファイル一覧プロバイダー。

  ExternalFolderItemsProvider call(String? folderPath) =>
      ExternalFolderItemsProvider._(argument: folderPath, from: this);

  @override
  String toString() => r'externalFolderItemsProvider';
}

/// 特定の外部参照フォルダ内のファイル一覧プロバイダー。

abstract class _$ExternalFolderItems extends $AsyncNotifier<List<MediaItem>> {
  late final _$args = ref.$arg as String?;
  String? get folderPath => _$args;

  FutureOr<List<MediaItem>> build(String? folderPath);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<MediaItem>>, List<MediaItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<MediaItem>>, List<MediaItem>>,
              AsyncValue<List<MediaItem>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// 外部参照のルート階層にある個別ファイル一覧プロバイダー。

@ProviderFor(ExternalRootItems)
final externalRootItemsProvider = ExternalRootItemsProvider._();

/// 外部参照のルート階層にある個別ファイル一覧プロバイダー。
final class ExternalRootItemsProvider
    extends $AsyncNotifierProvider<ExternalRootItems, List<MediaItem>> {
  /// 外部参照のルート階層にある個別ファイル一覧プロバイダー。
  ExternalRootItemsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'externalRootItemsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$externalRootItemsHash();

  @$internal
  @override
  ExternalRootItems create() => ExternalRootItems();
}

String _$externalRootItemsHash() => r'697419ea33270486220f0ee099249a3ce047b640';

/// 外部参照のルート階層にある個別ファイル一覧プロバイダー。

abstract class _$ExternalRootItems extends $AsyncNotifier<List<MediaItem>> {
  FutureOr<List<MediaItem>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<MediaItem>>, List<MediaItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<MediaItem>>, List<MediaItem>>,
              AsyncValue<List<MediaItem>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
