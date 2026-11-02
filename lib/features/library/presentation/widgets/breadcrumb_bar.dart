import 'package:flutter/material.dart';
import 'package:private_shelf/shared/widgets/feedback/app_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/features/library/presentation/providers/folder_summary_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/app_popup_menu_item.dart';

class BreadcrumbBar extends ConsumerStatefulWidget {
  final String? currentPath;
  final String rootLabel;
  final String? physicalPath;
  final void Function(String? path) onPathSelected;

  const BreadcrumbBar({
    super.key,
    required this.currentPath,
    required this.rootLabel,
    this.physicalPath,
    required this.onPathSelected,
  });

  @override
  ConsumerState<BreadcrumbBar> createState() => _BreadcrumbBarState();
}

class _BreadcrumbBarState extends ConsumerState<BreadcrumbBar> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollToEnd(animated: false);
  }

  @override
  void didUpdateWidget(covariant BreadcrumbBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      _scrollToEnd(animated: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  String _truncate(String text) {
    final chars = text.characters;
    if (chars.length <= 16) return text;
    final prefix = chars.take(9).toString();
    final suffix = chars.takeLast(4).toString();
    return '$prefix...$suffix';
  }

  String _safeDecodeUriComponent(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  List<_BreadcrumbSegment> _segments() {
    if (widget.currentPath == null || widget.currentPath!.isEmpty) {
      return [
        _BreadcrumbSegment(
          label: widget.rootLabel,
          path: null,
          parentPath: null,
          isRoot: true,
          canNavigate: false,
        ),
      ];
    }

    final normalizedPath = p.normalize(widget.currentPath!);
    final allParts = p
        .split(normalizedPath)
        .where((part) => part != '.' && part != '/' && part.isNotEmpty)
        .toList();

    // 内部ストレージのパス体系で先頭が 'library' の場合、ルートラベル（内部ストレージ）に包含されるため除外
    final hasLibraryPrefix = allParts.isNotEmpty && allParts.first == 'library';
    final parts = hasLibraryPrefix ? allParts.sublist(1) : allParts;

    final segments = <_BreadcrumbSegment>[
      _BreadcrumbSegment(
        label: widget.rootLabel,
        path: null,
        parentPath: null,
        isRoot: true,
        canNavigate: parts.isNotEmpty,
      ),
    ];

    if (parts.isEmpty) return segments;

    var cumulativePath = hasLibraryPrefix ? 'library' : '';
    String? currentParentPath;
    for (var index = 0; index < parts.length; index++) {
      final part = parts[index];
      currentParentPath = cumulativePath.isEmpty || cumulativePath == 'library'
          ? null
          : cumulativePath;
      cumulativePath = cumulativePath.isEmpty
          ? part
          : p.join(cumulativePath, part);
      segments.add(
        _BreadcrumbSegment(
          label: _safeDecodeUriComponent(part),
          path: cumulativePath,
          parentPath: currentParentPath,
          canNavigate: index < parts.length - 1,
        ),
      );
    }
    return segments;
  }

  Future<void> _showSiblingMenu(
    _BreadcrumbSegment segment,
    BuildContext itemContext,
  ) async {
    final siblings = await ref.read(
      siblingFoldersProvider(segment.parentPath).future,
    );
    if (!mounted || !itemContext.mounted || siblings.length <= 1) return;

    await ref.read(feedbackServiceProvider).lightImpact();
    if (!mounted || !itemContext.mounted) return;

    final itemRenderBox = itemContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (itemRenderBox == null || overlay == null) return;

    final position = RelativeRect.fromRect(
      itemRenderBox.localToGlobal(Offset.zero) & itemRenderBox.size,
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: siblings.map((item) {
        final isCurrent = item.path == segment.path;
        final folderName = p.basename(item.path);
        return AppPopupMenuItem<String>(
          value: item.path,
          iconData: isCurrent ? Icons.folder_open : Icons.folder_outlined,
          iconColor: isCurrent
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          title: Text(
            folderName,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? Theme.of(context).colorScheme.primary : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isCurrent
              ? Icon(
                  Icons.check,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
        );
      }).toList(),
    );

    if (selected != null && selected != segment.path) {
      widget.onPathSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final segments = _segments();
    final hasNestedSegments = segments.length > 1;
    final rootSegment = segments.first;

    return Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          if (hasNestedSegments) ...[
            Semantics(
              button: rootSegment.canNavigate,
              label: l10n.libraryBreadcrumbRoot(rootSegment.label),
              hint: rootSegment.canNavigate
                  ? l10n.libraryBreadcrumbNavigateHint(rootSegment.label)
                  : null,
              child: IconButton(
                key: const ValueKey('breadcrumb-root'),
                tooltip: rootSegment.label,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                onPressed: rootSegment.canNavigate
                    ? () => widget.onPathSelected(rootSegment.path)
                    : null,
                icon: Icon(
                  Icons.home_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(
                left: hasNestedSegments ? 4 : 16,
                right: 16,
              ),
              itemCount: hasNestedSegments
                  ? segments.length - 1
                  : segments.length,
              separatorBuilder: (context, index) => Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              itemBuilder: (context, index) {
                final segmentIndex = hasNestedSegments ? index + 1 : index;
                final segment = segments[segmentIndex];
                final isLast = segmentIndex == segments.length - 1;
                final semanticLabel = segment.isRoot
                    ? l10n.libraryBreadcrumbRoot(segment.label)
                    : segment.label;

                return Builder(
                  builder: (itemContext) {
                    return Semantics(
                      button: segment.canNavigate,
                      selected: isLast,
                      label: semanticLabel,
                      hint: segment.canNavigate
                          ? l10n.libraryBreadcrumbNavigateHint(segment.label)
                          : null,
                      child: InkWell(
                        onTap: segment.canNavigate
                            ? () => widget.onPathSelected(segment.path)
                            : null,
                        onLongPress: !segment.isRoot
                            ? () => _showSiblingMenu(segment, itemContext)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: isLast && !segment.isRoot
                              ? BoxDecoration(
                                  color: theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(6),
                                )
                              : null,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (segment.isRoot) ...[
                                  Icon(
                                    Icons.home_outlined,
                                    size: 17,
                                    color: isLast
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                ] else if (isLast) ...[
                                  Icon(
                                    Icons.folder_open_rounded,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                ] else ...[
                                  Icon(
                                    Icons.folder_outlined,
                                    size: 15,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                ExcludeSemantics(
                                  child: Text(
                                    _truncate(segment.label),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isLast
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                      fontWeight: isLast
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (!segment.isRoot) ...[
                                  const SizedBox(width: 2),
                                  IconButton(
                                    tooltip: l10n.libraryBreadcrumbSiblingMenu(
                                      segment.label,
                                    ),
                                    constraints: const BoxConstraints.tightFor(
                                      width: 48,
                                      height: 48,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    onPressed: () =>
                                        _showSiblingMenu(segment, itemContext),
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                      size: 20,
                                      color: isLast
                                          ? theme.colorScheme.primary
                                                .withValues(alpha: 0.8)
                                          : theme.colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (widget.physicalPath != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.copy_all, size: 20),
                tooltip: l10n.libraryCopyPath,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.physicalPath!));
                  AppSnackBarMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.libraryPathCopied),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _BreadcrumbSegment {
  final String label;
  final String? path;
  final String? parentPath;
  final bool isRoot;
  final bool canNavigate;

  const _BreadcrumbSegment({
    required this.label,
    required this.path,
    this.parentPath,
    required this.canNavigate,
    this.isRoot = false,
  });
}
