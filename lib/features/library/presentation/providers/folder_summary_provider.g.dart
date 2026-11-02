// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'folder_summary_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 指定したフォルダパス配下の直下アイテム数（フォルダ/ファイル）を集計して返すプロバイダー

@ProviderFor(folderSummary)
final folderSummaryProvider = FolderSummaryFamily._();

/// 指定したフォルダパス配下の直下アイテム数（フォルダ/ファイル）を集計して返すプロバイダー

final class FolderSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<FolderSummary>,
          FolderSummary,
          FutureOr<FolderSummary>
        >
    with $FutureModifier<FolderSummary>, $FutureProvider<FolderSummary> {
  /// 指定したフォルダパス配下の直下アイテム数（フォルダ/ファイル）を集計して返すプロバイダー
  FolderSummaryProvider._({
    required FolderSummaryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'folderSummaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$folderSummaryHash();

  @override
  String toString() {
    return r'folderSummaryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<FolderSummary> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FolderSummary> create(Ref ref) {
    final argument = this.argument as String;
    return folderSummary(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FolderSummaryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$folderSummaryHash() => r'09bb7c136253c9e19af13d063ba431d3fb37cf83';

/// 指定したフォルダパス配下の直下アイテム数（フォルダ/ファイル）を集計して返すプロバイダー

final class FolderSummaryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<FolderSummary>, String> {
  FolderSummaryFamily._()
    : super(
        retry: null,
        name: r'folderSummaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 指定したフォルダパス配下の直下アイテム数（フォルダ/ファイル）を集計して返すプロバイダー

  FolderSummaryProvider call(String folderPath) =>
      FolderSummaryProvider._(argument: folderPath, from: this);

  @override
  String toString() => r'folderSummaryProvider';
}

/// 指定した親パス配下のフォルダ一覧（MediaItem）を返すプロバイダー（パンくずリストでの兄弟ジャンプ用）

@ProviderFor(siblingFolders)
final siblingFoldersProvider = SiblingFoldersFamily._();

/// 指定した親パス配下のフォルダ一覧（MediaItem）を返すプロバイダー（パンくずリストでの兄弟ジャンプ用）

final class SiblingFoldersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MediaItem>>,
          List<MediaItem>,
          FutureOr<List<MediaItem>>
        >
    with $FutureModifier<List<MediaItem>>, $FutureProvider<List<MediaItem>> {
  /// 指定した親パス配下のフォルダ一覧（MediaItem）を返すプロバイダー（パンくずリストでの兄弟ジャンプ用）
  SiblingFoldersProvider._({
    required SiblingFoldersFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'siblingFoldersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$siblingFoldersHash();

  @override
  String toString() {
    return r'siblingFoldersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MediaItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MediaItem>> create(Ref ref) {
    final argument = this.argument as String?;
    return siblingFolders(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SiblingFoldersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$siblingFoldersHash() => r'ceeb1ea416c2fefa891db742f5892c92ee1b3087';

/// 指定した親パス配下のフォルダ一覧（MediaItem）を返すプロバイダー（パンくずリストでの兄弟ジャンプ用）

final class SiblingFoldersFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<MediaItem>>, String?> {
  SiblingFoldersFamily._()
    : super(
        retry: null,
        name: r'siblingFoldersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 指定した親パス配下のフォルダ一覧（MediaItem）を返すプロバイダー（パンくずリストでの兄弟ジャンプ用）

  SiblingFoldersProvider call(String? parentPath) =>
      SiblingFoldersProvider._(argument: parentPath, from: this);

  @override
  String toString() => r'siblingFoldersProvider';
}
