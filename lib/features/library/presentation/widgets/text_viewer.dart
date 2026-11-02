import 'dart:convert';
import 'viewer/content_ready.dart';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;

import 'package:private_shelf/core/error/user_safe_error_message.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/external_file_preview_provider.dart';
import 'package:private_shelf/features/library/presentation/widgets/viewer_state_panel.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

/// テキスト・Markdownファイルのプレビュー表示ウィジェット
class TextViewer extends ConsumerWidget {
  final MediaItem item;
  final bool renderContent;
  final VoidCallback? onTap;
  final VoidCallback? onContentReady;

  const TextViewer({
    super.key,
    required this.item,
    this.renderContent = true,
    this.onTap,
    this.onContentReady,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.requiresSourceAccess) {
      final previewAsync = ref.watch(externalFilePreviewProvider(item));
      return previewAsync.when(
        data: (tempPath) {
          if (tempPath != null) {
            return _TextFileView(
              file: File(tempPath),
              item: item,
              isMarkdown: item.isMarkdown,
              renderContent: renderContent,
              onTap: onTap,
              onContentReady: onContentReady,
            );
          }
          return ViewerStatePanel(
            kind: ViewerFailureKind.missing,
            onRetry: () => ref.invalidate(externalFilePreviewProvider(item)),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ViewerStatePanel(
          kind: ViewerFailureKind.unknown,
          message: userSafeErrorMessage(err, AppLocalizations.of(context)!),
          onRetry: () => ref.invalidate(externalFilePreviewProvider(item)),
        ),
      );
    }

    final docsPath = ref.watch(appDocumentsPathSyncProvider);
    final file = File(p.join(docsPath, item.path));

    return _TextFileView(
      file: file,
      item: item,
      isMarkdown: item.isMarkdown,
      renderContent: renderContent,
      onTap: onTap,
      onContentReady: onContentReady,
    );
  }
}

class _TextFileView extends StatefulWidget {
  final File file;
  final MediaItem item;
  final bool isMarkdown;
  final bool renderContent;
  final VoidCallback? onTap;
  final VoidCallback? onContentReady;

  const _TextFileView({
    required this.file,
    required this.item,
    required this.isMarkdown,
    required this.renderContent,
    this.onTap,
    this.onContentReady,
  });

  @override
  State<_TextFileView> createState() => _TextFileViewState();
}

class _TextFileViewState extends State<_TextFileView> {
  static const int _maxSafeSizeBytes = 2 * 1024 * 1024; // 2MB
  static const int _maxInAppSizeBytes = 16 * 1024 * 1024; // 16MB
  static const int _maxRichLayoutSizeBytes = 256 * 1024;

  late Future<_TextLoadResult> _contentFuture;
  bool _forceLoadLargeFile = false;

  @override
  void initState() {
    super.initState();
    _contentFuture = _loadTextContent();
  }

  @override
  void didUpdateWidget(covariant _TextFileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _forceLoadLargeFile = false;
      _contentFuture = _loadTextContent();
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  Future<_TextLoadResult> _loadTextContent() async {
    if (!await widget.file.exists()) return const _TextLoadResult.missing();
    final length = await widget.file.length();
    if (length > _maxInAppSizeBytes ||
        (length > _maxSafeSizeBytes && !_forceLoadLargeFile)) {
      return _TextLoadResult.tooLarge(fileSize: length);
    }

    if (length > _maxRichLayoutSizeBytes) {
      final filePath = widget.file.path;
      final chunks = await Isolate.run(() => _readUtf8Chunks(filePath));
      return _TextLoadResult.success(chunks: chunks, fileSize: length);
    }

    final bytes = await widget.file.readAsBytes();
    String text;
    try {
      // 不正な文字コードシーケンスがあってもクラッシュさせず置換文字で安全にデコード
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      // UTF-8 デコード失敗時は Latin1 にフォールバック
      text = latin1.decode(bytes);
    }
    return _TextLoadResult.success(content: text, fileSize: length);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (!widget.renderContent) {
      // Start the asynchronous read in initState, but postpone expensive text
      // or Markdown layout until the swipe has settled on this page.
      return const ColoredBox(color: Colors.black);
    }

    return FutureBuilder<_TextLoadResult>(
      future: _contentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final result = snapshot.data!;

          if (result.isMissing) {
            return const ViewerStatePanel(kind: ViewerFailureKind.missing);
          }

          if (result.isTooLarge) {
            final formattedSize = _formatBytes(result.fileSize);
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: colorScheme.error,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.viewerFileTooLarge,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.viewerFileTooLargeDesc(formattedSize),
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () async {
                        await OpenFile.open(widget.file.path);
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(l10n.viewerOpenExternal),
                    ),
                    if (result.fileSize <= _maxInAppSizeBytes) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _forceLoadLargeFile = true;
                            _contentFuture = _loadTextContent();
                          });
                        },
                        child: Text(l10n.viewerOpenAnyway),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          reportViewerContentReady(context, widget.onContentReady);
          final chunks = result.chunks;
          if (chunks != null) {
            return _VirtualizedTextView(chunks: chunks, onTap: widget.onTap);
          }

          final content = result.content ?? '';
          final topPadding = MediaQuery.paddingOf(context).top + 16.0;
          final bottomPadding = MediaQuery.paddingOf(context).bottom + 16.0;
          final padding = EdgeInsets.fromLTRB(
            16.0,
            topPadding,
            16.0,
            bottomPadding,
          );

          if (widget.isMarkdown) {
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onTap,
              child: Markdown(
                data: content,
                // 文書由来のURL・ローカルパス・assetを自動で開かない。
                imageBuilder: (uri, title, alt) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image_not_supported_outlined),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        (alt?.trim().isNotEmpty ?? false)
                            ? '${l10n.viewerMarkdownImageBlocked}: $alt'
                            : l10n.viewerMarkdownImageBlocked,
                      ),
                    ),
                  ],
                ),
                selectable: true,
                padding: padding,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                      p: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      h1: TextStyle(color: colorScheme.onSurface),
                      h2: TextStyle(color: colorScheme.onSurface),
                      h3: TextStyle(color: colorScheme.onSurface),
                      h4: TextStyle(color: colorScheme.onSurface),
                      h5: TextStyle(color: colorScheme.onSurface),
                      h6: TextStyle(color: colorScheme.onSurface),
                      listBullet: TextStyle(color: colorScheme.onSurface),
                    ),
              ),
            );
          } else {
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onTap,
              child: SingleChildScrollView(
                padding: padding,
                child: SelectionArea(
                  child: Text(
                    content,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            );
          }
        } else if (snapshot.hasError) {
          return ViewerStatePanel(
            kind: ViewerFailureKind.decodeFailed,
            message: userSafeErrorMessage(snapshot.error, l10n),
            onRetry: () {
              setState(() => _contentFuture = _loadTextContent());
            },
            onOpenExternal: () => OpenFile.open(widget.file.path),
          );
        }
        return Center(
          child: Text(
            l10n.commonLoading,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        );
      },
    );
  }
}

class _TextLoadResult {
  final bool isTooLarge;
  final bool isMissing;
  final int fileSize;
  final String? content;
  final List<String>? chunks;

  const _TextLoadResult._({
    required this.isTooLarge,
    required this.isMissing,
    required this.fileSize,
    this.content,
    this.chunks,
  });

  const _TextLoadResult.missing()
    : isTooLarge = false,
      isMissing = true,
      fileSize = 0,
      content = null,
      chunks = null;

  factory _TextLoadResult.tooLarge({required int fileSize}) {
    return _TextLoadResult._(
      isTooLarge: true,
      isMissing: false,
      fileSize: fileSize,
    );
  }

  factory _TextLoadResult.success({
    required int fileSize,
    String? content,
    List<String>? chunks,
  }) {
    assert((content == null) != (chunks == null));
    return _TextLoadResult._(
      isTooLarge: false,
      isMissing: false,
      fileSize: fileSize,
      content: content,
      chunks: chunks,
    );
  }
}

class _VirtualizedTextView extends StatelessWidget {
  const _VirtualizedTextView({required this.chunks, this.onTap});

  final List<String> chunks;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final topPadding = MediaQuery.paddingOf(context).top + 16.0;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 16.0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: ListView.builder(
        key: const Key('virtualized_text_view'),
        padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
        scrollCacheExtent: const ScrollCacheExtent.pixels(800),
        itemCount: chunks.length,
        itemBuilder: (context, index) => SelectionArea(
          child: Text(
            chunks[index],
            style: TextStyle(color: color, fontSize: 14, height: 1.5),
          ),
        ),
      ),
    );
  }
}

const int _virtualTextChunkLength = 2000;

Future<List<String>> _readUtf8Chunks(String filePath) async {
  final chunks = <String>[];
  var carry = '';
  final decoded = File(
    filePath,
  ).openRead().transform(const Utf8Decoder(allowMalformed: true));
  await for (final piece in decoded) {
    final text = carry + piece;
    var start = 0;
    while (text.length - start >= _virtualTextChunkLength) {
      var end = start + _virtualTextChunkLength;
      if (end < text.length &&
          _isHighSurrogate(text.codeUnitAt(end - 1)) &&
          _isLowSurrogate(text.codeUnitAt(end))) {
        end--;
      }
      chunks.add(text.substring(start, end));
      start = end;
    }
    carry = text.substring(start);
  }
  if (carry.isNotEmpty) chunks.add(carry);
  return chunks;
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;
