import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/data/repositories/media_repository_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_filter.dart';
import 'package:private_shelf/features/library/presentation/providers/secret_mode_provider.dart';

part 'tree_view_state_provider.g.dart';

/// 階層情報（depth, 展開状態）を付加したメディアアイテム
class TreeMediaItem {
  final MediaItem item;
  final int depth;
  final bool isExpanded;
  final bool hasChildren;

  const TreeMediaItem({
    required this.item,
    this.depth = 0,
    this.isExpanded = false,
    this.hasChildren = false,
  });
}

/// 展開されているフォルダパスの集合を管理するプロバイダー
@riverpod
class ExpandedFoldersNotifier extends _$ExpandedFoldersNotifier {
  @override
  Set<String> build() => <String>{};

  void toggle(String folderPath) {
    if (state.contains(folderPath)) {
      state = {...state}..remove(folderPath);
    } else {
      state = {...state, folderPath};
    }
  }

  void collapseAll() {
    state = <String>{};
  }

  bool isExpanded(String folderPath) => state.contains(folderPath);
}

/// 指定したフォルダパス配下の直下アイテム一覧を監視する。
@riverpod
Stream<List<MediaItem>> folderChildren(
  Ref ref,
  String folderPath,
) async* {
  final repository = await ref.watch(mediaRepositoryProvider.future);
  final isSecretMode = ref.watch(secretModeProvider).value ?? false;

  final filter = MediaFilter(
    parentPath: folderPath,
    isHidden: isSecretMode ? null : false,
  );

  yield* repository.watchAll(filter: filter).map((items) {
    final validItems = items.where((i) => !i.isTrashed).toList();
    // フォルダを先、ファイルを後にソート
    validItems.sort((a, b) {
      if (a.type == b.type) return a.path.compareTo(b.path);
      return a.type == MediaType.folder ? -1 : 1;
    });
    return validItems;
  });
}

/// 展開中のフォルダを一つのリストに平坦化し、画面側で可視行だけを構築する。
@riverpod
List<TreeMediaItem> treeMediaItems(
  Ref ref,
  List<MediaItem> rootItems,
) {
  final expandedPaths = ref.watch(expandedFoldersNotifierProvider);
  final result = <TreeMediaItem>[];
  final visited = <String>{};

  final pending = <({MediaItem item, int depth})>[
    for (final item in rootItems.reversed) (item: item, depth: 0),
  ];
  while (pending.isNotEmpty) {
    final node = pending.removeLast();
    final item = node.item;
    final isFolder = item.type == MediaType.folder;
    final isExpanded = isFolder && expandedPaths.contains(item.path);
    if (isExpanded && visited.contains(item.path)) continue;
    result.add(
      TreeMediaItem(
        item: item,
        depth: node.depth,
        isExpanded: isExpanded,
        hasChildren: isFolder,
      ),
    );
    // 壊れた親子関係や循環があっても同じフォルダを展開し続けない。
    if (isExpanded && visited.add(item.path)) {
      final children = ref.watch(folderChildrenProvider(item.path));
      for (final child
          in (children.value ?? const <MediaItem>[]).reversed) {
        pending.add((item: child, depth: node.depth + 1));
      }
    }
  }
  return result;
}
