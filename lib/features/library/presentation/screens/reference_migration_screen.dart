import 'dart:io';
import '../../../security/presentation/utils/security_action_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../gen_l10n/app_localizations.dart';
import '../../data/services/external_storage_service.dart';
import '../../data/services/reference_migration_service.dart';
import '../../domain/models/media_item.dart';
import '../providers/reference_migration_provider.dart';

class ReferenceMigrationScreen extends ConsumerStatefulWidget {
  const ReferenceMigrationScreen({super.key});
  @override
  ConsumerState<ReferenceMigrationScreen> createState() =>
      _ReferenceMigrationScreenState();
}

class _ReferenceMigrationScreenState
    extends ConsumerState<ReferenceMigrationScreen> {
  bool _busy = false;
  bool _authorized = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final allowed = await SecurityActionGuard.requireAuth(context, ref);
      if (!mounted) return;
      if (allowed) {
        setState(() => _authorized = true);
      } else {
        Navigator.of(context).pop();
      }
    });
  }

  int _done = 0, _total = 0;
  String? _message;
  ReferenceMigrationService? _service;

  Future<void> _run(
    Future<void> Function(ReferenceMigrationService) action,
  ) async {
    setState(() {
      _busy = true;
      _message = null;
      _done = 0;
      _total = 0;
    });
    try {
      _service = await ref.read(referenceMigrationServiceProvider.future);
      await action(_service!);
      if (mounted) {
        setState(
          () => _message = AppLocalizations.of(
            context,
          )!.referenceMigrationSuccess,
        );
      }
    } on MigrationInterrupted {
      if (mounted) {
        setState(
          () =>
              _message = AppLocalizations.of(context)!.referenceMigrationPaused,
        );
      }
    } catch (error) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        final reason =
            error is StateError && error.message == 'migration_recovery_pending'
            ? l.referenceMigrationRecoveryPending
            : error is StateError && error.message == 'migration_changed'
            ? l.referenceMigrationChanged
            : error is FileSystemException && error.message.contains('storage')
            ? l.referenceMigrationStorageFailure
            : error is FileSystemException ||
                  (error is StateError &&
                      error.message == 'migration_source_changed')
            ? l.referenceMigrationSourceFailure
            : l.referenceMigrationFailure;
        setState(() => _message = reason);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(referenceMigrationInventoryProvider);
      }
    }
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) {
          final l = AppLocalizations.of(context)!;
          return AlertDialog(
            scrollable: true,
            title: Text(l.referenceMigrationTitle),
            content: Text(text),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.commonConfirm),
              ),
            ],
          );
        },
      ) ??
      false;

  Future<void> _migrate(ReferenceMigrationGroup group) async {
    final l = AppLocalizations.of(context)!;
    if (!await _confirm('${group.title}\n${l.referenceMigrationConfirm}')) {
      return;
    }
    await _run(
      (service) => service.migrate(
        group,
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _done = done;
              _total = total;
            });
          }
        },
      ),
    );
  }

  Future<void> _reconnect(ReferenceMigrationGroup group, MediaItem item) async {
    if (!await _confirm(
      AppLocalizations.of(context)!.referenceMigrationReconnectConfirm,
    )) {
      return;
    }
    await _run((service) async {
      final storage = await ref.read(externalStorageServiceProvider.future);
      final files = await storage.pickFiles();
      if (files.isEmpty) throw MigrationInterrupted();
      if (files.length != 1) throw StateError('Select one source');
      await service.reconnect(group, item, files.single);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (!_authorized) {
      return Scaffold(
        appBar: AppBar(title: Text(l.referenceMigrationTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final inventory = ref.watch(referenceMigrationInventoryProvider);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(l.referenceMigrationTitle)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.referenceMigrationDescription),
            const SizedBox(height: 16),
            if (_message != null)
              Semantics(liveRegion: true, child: Text(_message!)),
            if (_busy) ...[
              LinearProgressIndicator(
                value: _total == 0 ? null : _done / _total,
              ),
              Text('$_done / $_total'),
              TextButton(
                onPressed: () => _service?.cancel(),
                child: Text(l.referenceMigrationPause),
              ),
            ],
            inventory.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text(l.referenceMigrationFailure),
              data: (groups) => Column(
                children: [
                  if (groups.isEmpty) Text(l.referenceMigrationEmpty),
                  for (final group in groups)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              group.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              l.referenceMigrationCounts(
                                group.files,
                                group.knownBytes,
                                group.unknownSizes,
                              ),
                            ),
                            if (group.isTrashed)
                              Text(l.referenceMigrationTrash),
                            FilledButton(
                              onPressed: _busy ? null : () => _migrate(group),
                              child: Text(l.referenceMigrationCopy),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run((service) async {
                                      final snapshot = await service
                                          .exportSnapshot(group);
                                      if (!context.mounted) return;
                                      final box =
                                          context.findRenderObject()
                                              as RenderBox?;
                                      await SharePlus.instance.share(
                                        ShareParams(
                                          text: snapshot,
                                          sharePositionOrigin: box == null
                                              ? null
                                              : box.localToGlobal(Offset.zero) &
                                                    box.size,
                                        ),
                                      );
                                    }),
                              child: Text(l.referenceMigrationExport),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      if (await _confirm(
                                        l.referenceMigrationRemoveConfirm,
                                      )) {
                                        await _run(
                                          (service) =>
                                              service.removeReferences(group),
                                        );
                                      }
                                    },
                              child: Text(l.referenceMigrationRemove),
                            ),
                            ExpansionTile(
                              title: Text(l.referenceMigrationReconnect),
                              children: [
                                for (final item in group.items.where(
                                  (i) => i.type == MediaType.file,
                                ))
                                  ListTile(
                                    title: Text(
                                      item.originalPath.isEmpty
                                          ? item.path
                                          : item.originalPath,
                                    ),
                                    trailing: const Icon(Icons.link),
                                    onTap: _busy
                                        ? null
                                        : () => _reconnect(group, item),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run((service) => service.cleanup()),
              child: Text(l.referenceMigrationCleanup),
            ),
          ],
        ),
      ),
    );
  }
}
