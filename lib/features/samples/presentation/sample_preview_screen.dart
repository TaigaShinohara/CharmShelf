import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../data/sample_preview_service.dart';
import '../domain/sample_catalog.dart';

/// A separate, read-only experience: no library, history or player dependencies.
class SamplePreviewScreen extends ConsumerStatefulWidget {
  const SamplePreviewScreen({super.key, this.onAddFiles});

  final VoidCallback? onAddFiles;

  @override
  ConsumerState<SamplePreviewScreen> createState() =>
      _SamplePreviewScreenState();
}

class _SamplePreviewScreenState extends ConsumerState<SamplePreviewScreen> {
  SampleKind _kind = SampleKind.photos;
  int _page = 0;

  String _title(AppLocalizations l10n, SampleKind kind) => switch (kind) {
    SampleKind.photos => l10n.samplePhotoTitle,
    SampleKind.art => l10n.sampleArtTitle,
    SampleKind.music => l10n.sampleMusicTitle,
    SampleKind.text => l10n.sampleTextTitle,
  };

  String _shortTitle(AppLocalizations l10n, SampleKind kind) => switch (kind) {
    SampleKind.photos => l10n.samplePhotoShort,
    SampleKind.art => l10n.sampleArtShort,
    SampleKind.music => l10n.sampleMusicShort,
    SampleKind.text => l10n.sampleTextShort,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final samples = SampleCatalog.forLocale(
      Localizations.localeOf(context).languageCode,
    );
    final selected = samples.firstWhere((sample) => sample.kind == _kind);
    final service = ref.watch(samplePreviewServiceProvider);
    final title = _title(l10n, _kind);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.samplePreviewTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              l10n.samplePreviewDescription,
              style: theme.textTheme.bodyLarge,
            ),
            AppSpacing.gapVerticalLg,
            LayoutBuilder(
              builder: (context, constraints) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(16) > 22;
                final columns = largeText || constraints.maxWidth < 240 ? 1 : 2;
                final width =
                    (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                    columns;
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final sample in samples)
                      SizedBox(
                        width: width,
                        child: _SampleChoice(
                          key: ValueKey('sample-shelf-${sample.kind.name}'),
                          title: _title(l10n, sample.kind),
                          shortTitle: _shortTitle(l10n, sample.kind),
                          icon: switch (sample.kind) {
                            SampleKind.photos => Icons.photo_outlined,
                            SampleKind.art => Icons.palette_outlined,
                            SampleKind.music => Icons.music_note_rounded,
                            SampleKind.text => Icons.description_outlined,
                          },
                          selected: sample.kind == _kind,
                          onSelected: () => setState(() {
                            _kind = sample.kind;
                            _page = 0;
                          }),
                        ),
                      ),
                  ],
                );
              },
            ),
            AppSpacing.gapVerticalLg,
            Text(title, style: theme.textTheme.headlineSmall),
            AppSpacing.gapVerticalSm,
            if (_kind == SampleKind.music) ...[
              Text(
                key: const ValueKey('sample-music-explanation'),
                l10n.sampleMusicDescription,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.gapVerticalSm,
            ],
            _SampleAssetView(
              key: ValueKey(selected.assets[_page]),
              path: selected.assets[_page],
              service: service,
              isText: _kind == SampleKind.text,
              label: title,
            ),
            if (selected.assets.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).previousPageTooltip,
                    onPressed: _page == 0
                        ? null
                        : () => setState(() => _page--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    l10n.samplePreviewPosition(
                      _page + 1,
                      selected.assets.length,
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                    onPressed: _page == selected.assets.length - 1
                        ? null
                        : () => setState(() => _page++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            AppSpacing.gapVerticalLg,
            Text(
              l10n.samplePreviewNotSaved,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.onAddFiles != null) ...[
              AppSpacing.gapVerticalMd,
              FilledButton.icon(
                onPressed: widget.onAddFiles,
                icon: const Icon(Icons.add),
                label: Text(l10n.samplePreviewAddFiles),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SampleChoice extends StatelessWidget {
  const _SampleChoice({
    super.key,
    required this.title,
    required this.shortTitle,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final String shortTitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      onTap: onSelected,
      child: ExcludeSemantics(
        child: Material(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: AppRadius.radiusMd,
          child: InkWell(
            onTap: onSelected,
            borderRadius: AppRadius.radiusMd,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: AppRadius.radiusMd,
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  AppSpacing.gapHorizontalSm,
                  Expanded(
                    child: Text(
                      shortTitle,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SampleAssetView extends StatefulWidget {
  const _SampleAssetView({
    super.key,
    required this.path,
    required this.service,
    required this.isText,
    required this.label,
  });

  final String path;
  final SamplePreviewService service;
  final bool isText;
  final String label;

  @override
  State<_SampleAssetView> createState() => _SampleAssetViewState();
}

class _SampleAssetViewState extends State<_SampleAssetView> {
  late Future<Uint8List> _load;

  @override
  void initState() {
    super.initState();
    _load = widget.service.load(widget.path);
  }

  Widget _error(AppLocalizations l10n) {
    return Column(
      children: [
        Text(l10n.samplePreviewLoadError),
        TextButton(
          onPressed: () {
            widget.service.discard(widget.path);
            setState(() {
              _load = widget.service.load(widget.path);
            });
          },
          child: Text(l10n.samplePreviewRetry),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<Uint8List>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _error(l10n);
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (widget.isText) {
          return Card(
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SelectableText(
                _readableSampleNote(
                  utf8.decode(snapshot.data!, allowMalformed: true),
                ),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }
        return ClipRRect(
          borderRadius: AppRadius.radiusLg,
          child: ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: Image.memory(
              snapshot.data!,
              semanticLabel: widget.label,
              height: 280,
              width: double.infinity,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, error, stackTrace) => Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _error(l10n),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _readableSampleNote(String raw) {
  return raw
      .split('\n')
      .map((line) {
        final trimmed = line.trimRight();
        final heading = RegExp(r'^#{1,6}\s+').firstMatch(trimmed);
        if (heading != null) return trimmed.substring(heading.end);
        if (trimmed.startsWith('> ')) return trimmed.substring(2);
        if (trimmed.startsWith('- ')) return '・ ${trimmed.substring(2)}';
        return trimmed;
      })
      .join('\n')
      .trim();
}
