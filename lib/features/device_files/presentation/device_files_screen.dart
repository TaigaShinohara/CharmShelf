import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../gen_l10n/app_localizations.dart';
import '../../library/domain/models/import_preview_source.dart';
import '../../library/presentation/screens/import_source_screen.dart';
import '../../library/presentation/screens/import_selection_screen.dart';
import '../../library/presentation/screens/media_viewer_screen.dart';
import '../../library/presentation/providers/import_flow_provider.dart';
import '../data/device_file_repository.dart';
import '../data/device_storage.dart';
import '../domain/device_file.dart';
import 'device_access_panel.dart';

class DeviceFilesScreen extends ConsumerStatefulWidget {
  const DeviceFilesScreen({super.key, this.selectForImport = false});
  final bool selectForImport;
  @override
  ConsumerState<DeviceFilesScreen> createState() => _DeviceFilesScreenState();
}

class _DeviceFilesScreenState extends ConsumerState<DeviceFilesScreen>
    with WidgetsBindingObserver {
  late final DeviceStorage _storage;
  DeviceFileRepository? _repository;
  final _search = TextEditingController();
  final _selected = <String, DeviceFile>{};
  List<DeviceFile> _roots = [], _entries = [], _locations = [];
  DeviceFile? _root, _directory;
  bool _allowed = false, _loading = true, _busy = false, _error = false;
  bool _indexed = false, _selecting = false;
  String? _extension;
  int _generation = 0, _count = 0, _skipped = 0;
  AppLocalizations get l => AppLocalizations.of(context)!;
  bool get _choosing => widget.selectForImport || _selecting;

  @override
  void initState() {
    super.initState();
    _storage = ref.read(deviceStorageProvider);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_storage.cancel().catchError((Object _) {}));
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_recheck());
  }

  Future<void> _recheck() async {
    try {
      final allowed = await _storage.allowed();
      if (!mounted) return;
      if (allowed != _allowed) await _load();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    await _storage.cancel();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
      _selected.clear();
    });
    try {
      final allowed = await _storage.allowed();
      final repository = await ref.read(deviceFileRepositoryProvider.future);
      final roots = allowed ? await _storage.roots() : <DeviceFile>[];
      final locations = <DeviceFile>[...roots];
      for (final root in roots) {
        final listing = await _storage.children(root.uri);
        locations.addAll(
          listing.entries.where(
            (e) =>
                e.directory &&
                const {
                  'Download',
                  'Downloads',
                  'Documents',
                  'Pictures',
                  'Movies',
                  'Music',
                  'DCIM',
                }.contains(e.name),
          ),
        );
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _allowed = allowed;
        _repository = repository;
        _roots = roots;
        _root = null;
        _directory = null;
        _entries = locations;
        _locations = locations;
        _indexed = false;
        _search.clear();
        _skipped = 0;
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _error = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _busy = false;
        });
      }
    }
  }

  DeviceFile _volume(DeviceFile entry) => _roots.firstWhere(
    (root) =>
        entry.uri == root.uri ||
        entry.uri.toFilePath().startsWith('${root.uri.toFilePath()}/'),
  );
  Future<void> _open(DeviceFile directory) async {
    final generation = ++_generation;
    await _storage.cancel();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
      _indexed = false;
      _search.clear();
    });
    try {
      await _storage.validate([directory]);
      final listing = await _storage.children(directory.uri);
      if (!mounted || generation != _generation) return;
      setState(() {
        _directory = directory;
        _root = _volume(directory);
        _entries = listing.entries;
        _skipped = listing.skipped;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = true;
          _entries = [];
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _goLocations() {
    _generation++;
    unawaited(_storage.cancel().catchError((Object _) {}));
    setState(() {
      _directory = null;
      _root = null;
      _entries = _locations;
      _indexed = false;
      _loading = false;
      _error = false;
      _search.clear();
    });
  }

  Future<void> _up() async {
    if (_directory == null || _directory!.uri == _root?.uri) {
      _goLocations();
      return;
    }
    try {
      await _open(
        await _storage.stat(Uri.file(p.dirname(_directory!.uri.toFilePath()))),
      );
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _scan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deviceIndexTitle),
        content: Text(l.deviceIndexExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.deviceIndexUpdate),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _count = 0;
      _error = false;
    });
    try {
      final listing = await _storage.scan(
        _roots,
        excluded: _repository!.excluded,
        onProgress: (count) {
          if (mounted && generation == _generation) {
            setState(() => _count = count);
          }
        },
      );
      if (!mounted || generation != _generation) return;
      _entries = listing.entries;
      if (!mounted || generation != _generation) return;
      setState(() {
        _indexed = false;
        _directory = null;
        _skipped = listing.skipped;
      });
    } on DeviceScanCancelled {
      /* The previous complete snapshot remains. */
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _error = true);
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    _generation++;
    await _storage.cancel();
    if (mounted) {
      setState(() {
        _busy = false;
        _loading = false;
      });
    }
  }

  Future<void> _exclude(DeviceFile entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deviceExclude),
        content: Text(l.deviceExcludeExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.deviceExclude),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository!.setExcluded({
        ..._repository!.excluded,
        '${entry.uri}',
      });
      if (mounted) setState(() {});
    } catch (_) {
      _message(l.deviceReadError);
    }
  }

  Future<void> _exclusions() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .65,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.deviceExclusions),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final uri in _repository!.excluded)
                        ListTile(
                          title: Text(Uri.parse(uri).toFilePath()),
                          trailing: IconButton(
                            icon: const Icon(Icons.undo),
                            tooltip: l.deviceInclude,
                            onPressed: () async {
                              try {
                                await _repository!.setExcluded(
                                  _repository!.excluded..remove(uri),
                                );
                                if (context.mounted) update(() {});
                                if (mounted) setState(() {});
                              } catch (_) {
                                _message(l.deviceReadError);
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _preview(DeviceFile entry) async {
    try {
      await _storage.validate([entry]);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MediaViewerScreen.preview(
            source: ImportPreviewSource(
              uri: entry.uri,
              name: entry.name,
              size: entry.size,
            ),
          ),
        ),
      );
    } catch (_) {
      _message(l.deviceChanged);
    }
  }

  void _toggle(DeviceFile entry) {
    final root = _volume(entry);
    // A single import review has one source-relative namespace.
    if (!entry.directory && !entry.supported) return;
    if (_selected.isNotEmpty &&
        _volume(_selected.values.first).uri != root.uri) {
      _message(l.deviceOneVolume);
      return;
    }
    setState(() {
      if (_selected.remove('${entry.uri}') == null) {
        _selected['${entry.uri}'] = entry;
      }
    });
  }

  Future<void> _finish() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      final tree = await _storage.selection(
        _volume(_selected.values.first),
        _selected.values.toList(),
      );
      if (!mounted || generation != _generation) return;
      if (!tree.isMedia) {
        _message(l.importSourceNoSupported);
        return;
      }
      if (widget.selectForImport) {
        Navigator.pop(context, ImportSourceSelection(tree: tree));
        return;
      }
      await ref
          .read(importFlowNotifierProvider.notifier)
          .startSourceSelection(tree);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ImportSelectionScreen()),
      );
    } on DeviceScanCancelled {
      /* explicit cancellation */
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _error = true);
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _fallback() async {
    final result = await Navigator.of(context).push<ImportSourceSelection>(
      MaterialPageRoute(builder: (_) => const ImportSourceScreen()),
    );
    if (!mounted || result == null) return;
    if (widget.selectForImport) {
      Navigator.pop(context, result);
      return;
    }
    final flow = ref.read(importFlowNotifierProvider.notifier);
    if (result.tree != null) {
      await flow.startSourceSelection(result.tree!);
    } else if (result.files != null) {
      await flow.startFilesScan(result.files!);
    } else if (result.folder != null) {
      flow.startScan(result.folder!);
    }
    if (mounted) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ImportSelectionScreen()),
      );
    }
  }

  List<DeviceFile> get _visible {
    final query = _search.text.trim().toLowerCase();
    final source = _indexed ? _repository?.entries ?? <DeviceFile>[] : _entries;
    return source.where((e) {
      final labels = _repository?.labels(e) ?? const DeviceFileLabels();

      if (_extension != null && e.extension != _extension) return false;
      return query.isEmpty ||
          [
            e.name,
            e.uri.toFilePath(),
            ...labels.tags,
            labels.catalog,
          ].any((v) => v.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l.commonClose,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.deviceFilesTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_allowed && !widget.selectForImport)
            IconButton(
              icon: Icon(_selecting ? Icons.close : Icons.checklist),
              tooltip: l.deviceSelectImport,
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _selecting = !_selecting;
                      _selected.clear();
                    }),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * .48,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_allowed && !_loading)
                        DeviceAccessPanel(onChanged: _load),
                      if (_allowed) ...[
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: _busy ? null : _goLocations,
                              child: Text(l.deviceLocations),
                            ),
                            if (_directory != null)
                              TextButton(
                                onPressed: _busy || _loading ? null : _up,
                                child: Text(l.importSourceUp),
                              ),
                            TextButton(
                              onPressed:
                                  _busy || _loading || _repository == null
                                  ? null
                                  : _scan,
                              child: Text(l.deviceIndexUpdate),
                            ),
                            TextButton(
                              onPressed: _busy || _repository == null
                                  ? null
                                  : _exclusions,
                              child: Text(l.deviceExclusions),
                            ),
                          ],
                        ),
                        if (_directory == null && !_indexed)
                          TextButton(
                            onPressed: _busy ? null : _fallback,
                            child: Text(l.deviceUsePicker),
                          ),
                        if (_directory != null)
                          Text(
                            _directory!.uri.toFilePath(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (_repository != null)
                          Text(
                            _repository!.indexedAt == null
                                ? l.deviceIndexEmpty
                                : l.deviceIndexDate(
                                    _repository!.indexedAt!
                                        .toLocal()
                                        .toString()
                                        .split('.')
                                        .first,
                                  ),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: _indexed
                                ? l.deviceSearchAll
                                : l.deviceSearchFolder,
                            prefixIcon: const Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilterChip(
                              label: Text(l.deviceSavedIndex),
                              selected: _indexed,
                              onSelected: _busy
                                  ? null
                                  : (v) => setState(() {
                                      _indexed = v;
                                      _extension = null;
                                    }),
                            ),
                            PopupMenuButton<String>(
                              tooltip: l.deviceType,
                              onSelected: (v) => setState(
                                () => _extension = v.isEmpty ? null : v,
                              ),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: '',
                                  child: Text(l.deviceAllTypes),
                                ),
                                for (final ext
                                    in ((_indexed
                                            ? _repository?.entries ?? []
                                            : _entries)
                                        .where((e) => !e.directory)
                                        .map((e) => e.extension)
                                        .toSet()
                                        .toList()
                                      ..sort()))
                                  PopupMenuItem(
                                    value: ext,
                                    child: Text(
                                      ext.isEmpty ? l.deviceAllTypes : ext,
                                    ),
                                  ),
                              ],
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(_extension ?? l.deviceType),
                              ),
                            ),
                          ],
                        ),
                        if ((_indexed ? _repository?.skipped ?? 0 : _skipped) >
                            0)
                          Text(
                            l.deviceSkipped(
                              _indexed ? _repository!.skipped : _skipped,
                            ),
                          ),
                      ],
                      if (_error) ...[
                        Text(l.deviceReadError),
                        TextButton(
                          onPressed: _busy ? null : _load,
                          child: Text(l.commonRetry),
                        ),
                      ],
                      if (_busy) ...[
                        Text(l.deviceScanning(_count)),
                        TextButton(
                          onPressed: _cancel,
                          child: Text(l.commonCancel),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_loading || _busy) const LinearProgressIndicator(),
              Expanded(
                child: !_allowed
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          TextButton(
                            onPressed: _busy ? null : _fallback,
                            child: Text(l.deviceUsePicker),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(l.deviceLater),
                          ),
                        ],
                      )
                    : items.isEmpty
                    ? Center(child: Text(l.deviceNoResults))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final entry = items[index];
                          final labels =
                              _repository?.labels(entry) ??
                              const DeviceFileLabels();
                          return ListTile(
                            leading: Icon(
                              entry.directory
                                  ? Icons.folder_outlined
                                  : Icons.insert_drive_file_outlined,
                            ),
                            title: Text(
                              entry.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_indexed)
                                  Text(
                                    entry.uri.toFilePath(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (labels.catalog.isNotEmpty ||
                                    labels.tags.isNotEmpty ||
                                    labels.favorite)
                                  Text(
                                    [
                                      if (labels.catalog.isNotEmpty)
                                        labels.catalog,
                                      ...labels.tags,
                                      if (labels.favorite) l.deviceFavorites,
                                    ].join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                            onTap: _busy || _loading
                                ? null
                                : () => entry.directory
                                      ? _open(entry)
                                      : _choosing
                                      ? _toggle(entry)
                                      : _preview(entry),
                            trailing: _choosing
                                ? Checkbox(
                                    value: _selected.containsKey(
                                      '${entry.uri}',
                                    ),
                                    semanticLabel: entry.name,
                                    onChanged:
                                        _busy ||
                                            _loading ||
                                            (!entry.directory &&
                                                !entry.supported)
                                        ? null
                                        : (_) => _toggle(entry),
                                  )
                                : PopupMenuButton<String>(
                                    tooltip: l.deviceExclude,
                                    enabled:
                                        !_busy && !_loading && entry.directory,
                                    onSelected: (_) => _exclude(entry),
                                    itemBuilder: (_) => [
                                      if (entry.directory)
                                        PopupMenuItem(
                                          value: 'exclude',
                                          child: Text(l.deviceExclude),
                                        ),
                                    ],
                                  ),
                          );
                        },
                      ),
              ),
              if (_choosing && _allowed)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .25,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextButton(
                          onPressed: _selected.isEmpty
                              ? null
                              : () => showModalBottomSheet<void>(
                                  context: context,
                                  builder: (context) => StatefulBuilder(
                                    builder: (context, update) => SafeArea(
                                      child: ListView(
                                        children: [
                                          for (final entry
                                              in _selected.values.toList())
                                            ListTile(
                                              title: Text(entry.name),
                                              subtitle: Text(
                                                entry.uri.toFilePath(),
                                              ),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.close),
                                                tooltip: l.deviceUnselect,
                                                onPressed: () {
                                                  setState(
                                                    () => _selected.remove(
                                                      '${entry.uri}',
                                                    ),
                                                  );
                                                  update(() {});
                                                },
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          child: Text(l.deviceSelected(_selected.length)),
                        ),
                        FilledButton(
                          onPressed: _selected.isEmpty || _busy || _loading
                              ? null
                              : _finish,
                          child: Text(l.importSourceReview),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
