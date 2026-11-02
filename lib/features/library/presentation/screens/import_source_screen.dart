import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_storage/shared_storage.dart' as saf;
import 'package:uuid/uuid.dart';
import '../../../../core/providers/shared_preferences_provider.dart';
import '../../../../gen_l10n/app_localizations.dart';
import '../../data/repositories/import_source_repository.dart';
import '../../data/repositories/media_repository_provider.dart';
import '../../data/services/external_storage_service.dart';
import '../../data/services/import_source_browser.dart';
import '../../domain/models/import_source.dart';
import '../../domain/models/file_tree.dart';
import '../helpers/import_picker_notification_helper.dart';
import '../providers/import_flow_provider.dart';
import 'import_selection_screen.dart';

class ImportSourceSelection {
  const ImportSourceSelection({this.tree, this.folder, this.files});
  final FileTreeNode? tree;
  final Uri? folder;
  final List<String>? files;
}

/// A single route: system Back always closes, directory navigation never pushes.
class ImportSourceScreen extends ConsumerStatefulWidget {
  const ImportSourceScreen({super.key, this.selectForImport = true});
  final bool selectForImport;
  @override
  ConsumerState<ImportSourceScreen> createState() => _ImportSourceScreenState();
}

class _ImportSourceScreenState extends ConsumerState<ImportSourceScreen> {
  ImportSourceRepository? _repository;
  late final ImportSourceBrowser _browser;
  List<ImportSource> _sources = [];
  ImportSource? _source;
  final List<ImportSourceEntry> _trail = [];
  List<ImportSourceEntry> _entries = [];
  final Map<String, ImportSourceEntry> _selected = {};
  bool _loading = true, _busy = false, _error = false;
  int _generation = 0;
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _browser = ref.read(importSourceBrowserProvider);
    unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_browser.cancel().catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final preferences = await ref.read(sharedPreferencesProvider.future);
      final repo = ImportSourceRepository(preferences);
      final sources = repo.read();
      if (!mounted) return;
      setState(() {
        _repository = repo;
        _sources = sources;
        _loading = false;
        _error = false;
      });
      // Durable cleanup; failures stay recorded for the next visit.
      if (repo.pendingReleases().isEmpty) return;
      final storage = await ref.read(externalStorageServiceProvider.future);
      for (final uri in repo.pendingReleases()) {
        try {
          await storage.releasePersistedAccess(uri);
          await repo.released(uri);
        } catch (_) {
          /* Keep the pending record. */
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  Future<void> _operation(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = false;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(ImportSource source) async {
    final generation = ++_generation;
    setState(() {
      _source = source;
      _trail.clear();
      _selected.clear();
      _entries = [];
      _loading = true;
      _error = false;
    });
    try {
      final root = await _browser.root(source.treeUri);
      final entries = await _browser.children(source, root);
      if (!mounted || generation != _generation) return;
      setState(() {
        _trail.add(root);
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  Future<void> _directory(List<ImportSourceEntry> trail) async {
    final source = _source!;
    final generation = ++_generation;
    unawaited(_browser.cancel().catchError((Object _) {}));
    setState(() {
      _trail
        ..clear()
        ..addAll(trail);
      _entries = [];
      _loading = true;
      _error = false;
    });
    try {
      final entries = await _browser.children(source, trail.last);
      if (!mounted || generation != _generation) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.importSourceContinue),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _register({ImportSource? replacing, Uri? existing}) =>
      _operation(() async {
        if (_repository == null) return;
        if (existing == null &&
            !await _confirm(
              l10n.importSourceAdd,
              l10n.importSourcePermissionBody,
            )) {
          return;
        }
        if (!mounted) return;
        final storage = await ref.read(externalStorageServiceProvider.future);
        final previous = await saf.persistedUriPermissions();
        final uri =
            existing ??
            await runImportPicker(
              pick: () => saf.openDocumentTree(grantWritePermission: false),
            );
        if (uri == null) return;
        var saved = false;
        try {
          final root = await _browser.root(uri);
          final candidate = ImportSource(
            id: replacing?.id ?? const Uuid().v4(),
            name: root.name,
            treeUri: uri,
          );
          await _browser.children(candidate, root);
          if (!mounted) return;
          if (replacing != null &&
              replacing.treeUri != uri &&
              !await _confirm(
                l10n.importSourceReconnect,
                l10n.importSourceReplaceBody,
              )) {
            return;
          }
          if (!mounted) return;
          // Replacing a location records its old grant for later safe cleanup.
          await _repository!.save(candidate);
          saved = true;
          if (!mounted) return;
          setState(() => _sources = _repository!.read());
          await _open(
            _sources.firstWhere(
              (source) => source.treeUri == candidate.treeUri,
            ),
          );
        } finally {
          if (!saved &&
              existing == null &&
              previous != null &&
              !previous.any((p) => p.uri == uri)) {
            // Preserve a newly granted URI until safe cleanup can be verified.
            await storage.releasePersistedAccess(uri);
          }
        }
      });

  Future<void> _existing() => _operation(() async {
    final repository = await ref.read(mediaRepositoryProvider.future);
    final result = await repository.getExternalCollections();
    if (result.isFailure) throw result.errorOrNull!;
    final folders = result.dataOrNull!
        .where(
          (f) => Uri.tryParse(f.path)?.pathSegments.contains('tree') == true,
        )
        .toList();
    if (!mounted) return;
    final uri = await showModalBottomSheet<Uri>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .6,
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.importSourceExisting),
              ),
              if (folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.importSourceNoExisting),
                ),
              for (final folder in folders)
                ListTile(
                  title: Text(folder.title),
                  onTap: () => Navigator.pop(context, Uri.parse(folder.path)),
                ),
            ],
          ),
        ),
      ),
    );
    if (uri == null || !mounted) return;
    final root = await _browser.root(uri);
    final candidate = ImportSource(
      id: const Uuid().v4(),
      name: root.name,
      treeUri: uri,
    );
    await _browser.children(candidate, root);
    if (!mounted) return;
    await _repository!.save(candidate);
    if (!mounted) return;
    setState(() => _sources = _repository!.read());
    await _open(
      _sources.firstWhere((source) => source.treeUri == candidate.treeUri),
    );
  });

  Future<void> _remove(ImportSource source) => _operation(() async {
    if (!await _confirm(l10n.importSourceRemove, l10n.importSourceRemoveBody) ||
        !mounted) {
      return;
    }
    await _repository!.remove(source);
    if (!mounted) return;
    setState(() => _sources = _repository!.read());
    final storage = await ref.read(externalStorageServiceProvider.future);
    await storage.releasePersistedAccess(source.treeUri);
    await _repository!.released(source.treeUri);
  });

  void _toggle(ImportSourceEntry entry) => setState(() {
    if (_selected.containsKey(entry.id)) {
      _selected.remove(entry.id);
    } else {
      _selected[entry.id] = entry;
    }
  });

  Future<void> _locations() async {
    if (_selected.isNotEmpty &&
        !await _confirm(l10n.importSourceLocations, l10n.importSourceDiscard)) {
      return;
    }
    if (!mounted) return;
    _generation++;
    unawaited(_browser.cancel().catchError((Object _) {}));
    setState(() {
      _source = null;
      _trail.clear();
      _entries = [];
      _selected.clear();
      _error = false;
      _loading = false;
    });
  }

  Future<void> _finish() => _operation(() async {
    final tree = await _browser.selection(_source!, _selected.values.toList());
    if (!mounted) return;
    if (!tree.isMedia) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importSourceNoSupported)));
      return;
    }
    await _completeSelection(ImportSourceSelection(tree: tree));
  });

  Future<void> _fallback(bool folder) => _operation(() async {
    ImportSourceSelection? selection;
    if (folder) {
      final storage = await ref.read(externalStorageServiceProvider.future);
      final uri = await runImportPicker(pick: storage.pickFolder);
      if (uri != null) selection = ImportSourceSelection(folder: uri);
    } else {
      final result = await runImportPicker(
        pick: () => FilePicker.pickFiles(type: FileType.any),
      );
      final paths = result?.map((e) => e.path).whereType<String>().toList();
      if (paths != null && paths.isNotEmpty) {
        selection = ImportSourceSelection(files: paths);
      }
    }
    if (mounted && selection != null) await _completeSelection(selection);
  });

  Future<void> _completeSelection(ImportSourceSelection selection) async {
    if (widget.selectForImport) {
      Navigator.pop(context, selection);
      return;
    }
    final flow = ref.read(importFlowNotifierProvider.notifier);
    if (selection.tree != null) {
      await flow.startSourceSelection(selection.tree!);
    } else if (selection.files != null) {
      await flow.startFilesScan(selection.files!);
    } else if (selection.folder != null) {
      flow.startScan(selection.folder!);
    } else {
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ImportSelectionScreen()),
    );
  }

  void _showSelected() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .5,
            child: ListView(
              children: [
                for (final entry in _selected.values.toList())
                  ListTile(
                    title: Text(entry.path.isEmpty ? entry.name : entry.path),
                    trailing: IconButton(
                      tooltip: l10n.importSourceUnselect,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _toggle(entry);
                        update(() {});
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('source-close'),
          tooltip: l10n.commonClose,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.importSourceTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .45,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (source != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: _busy ? null : _locations,
                                  child: Text(l10n.importSourceLocations),
                                ),
                                if (_trail.length > 1)
                                  TextButton.icon(
                                    key: const ValueKey('source-up'),
                                    onPressed: _busy
                                        ? null
                                        : () => _directory(
                                            _trail.sublist(
                                              0,
                                              _trail.length - 1,
                                            ),
                                          ),
                                    icon: const Icon(Icons.arrow_upward),
                                    label: Text(l10n.importSourceUp),
                                  ),
                              ],
                            ),
                            Text(
                              _trail.isEmpty
                                  ? source.name
                                  : _trail.map((e) => e.name).join(' / '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_trail.isNotEmpty)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.importSourceSelectFolder),
                                value: _selected.containsKey(_trail.last.id),
                                onChanged: _busy || _loading
                                    ? null
                                    : (_) => _toggle(_trail.last),
                              ),
                          ],
                        ),
                      ),
                    if (_busy || _loading) const LinearProgressIndicator(),
                    if (_error)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(l10n.importSourceUnavailable),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => source == null
                                            ? _load()
                                            : _trail.isEmpty
                                            ? _open(source)
                                            : _directory(List.of(_trail)),
                                  child: Text(l10n.importSourceRetry),
                                ),
                                if (source != null)
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _register(replacing: source),
                                    child: Text(l10n.importSourceReconnect),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: source == null
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_sources.isEmpty) Text(l10n.importSourceIntro),
                        const SizedBox(height: 16),
                        for (final item in _sources)
                          ListTile(
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(item.name),
                            onTap: _busy ? null : () => _open(item),
                            trailing: IconButton(
                              tooltip: l10n.importSourceRemove,
                              icon: const Icon(Icons.link_off),
                              onPressed: _busy ? null : () => _remove(item),
                            ),
                          ),
                        FilledButton.icon(
                          onPressed: _busy || _repository == null
                              ? null
                              : () => _register(),
                          icon: const Icon(Icons.add),
                          label: Text(l10n.importSourceAdd),
                        ),
                        TextButton(
                          onPressed: _busy || _repository == null
                              ? null
                              : _existing,
                          child: Text(l10n.importSourceExisting),
                        ),
                        const Divider(),
                        Text(l10n.importSourceFallback),
                        TextButton(
                          onPressed: _busy ? null : () => _fallback(false),
                          child: Text(l10n.libraryImportFile),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _fallback(true),
                          child: Text(l10n.libraryImportFolder),
                        ),
                      ],
                    )
                  : _entries.isEmpty
                  ? Center(
                      child: Text(
                        _loading || _error ? '' : l10n.importSourceEmpty,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        final selectable = entry.isDirectory || entry.supported;
                        return ListTile(
                          key: ValueKey(entry.id),
                          leading: Icon(
                            entry.isDirectory
                                ? Icons.folder_outlined
                                : Icons.insert_drive_file_outlined,
                          ),
                          title: Text(entry.name),
                          subtitle: !selectable
                              ? Text(l10n.importSourceUnsupported)
                              : null,
                          onTap: _busy || !selectable
                              ? null
                              : () => entry.isDirectory
                                    ? _directory([..._trail, entry])
                                    : _toggle(entry),
                          trailing: Checkbox(
                            semanticLabel: entry.name,
                            value: _selected.containsKey(entry.id),
                            onChanged: _busy || !selectable
                                ? null
                                : (_) => _toggle(entry),
                          ),
                        );
                      },
                    ),
            ),
            if (source != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .3,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextButton(
                        onPressed: _selected.isEmpty || _busy
                            ? null
                            : _showSelected,
                        child: Text(
                          l10n.importSourceSelected(
                            _selected.values
                                .where((e) => !e.isDirectory)
                                .length,
                            _selected.values.where((e) => e.isDirectory).length,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: _selected.isEmpty || _busy || _loading
                            ? null
                            : _finish,
                        child: Text(l10n.importSourceReview),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
