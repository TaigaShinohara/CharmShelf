import '../../../../core/services/operation_journal_service.dart';
import '../../domain/models/reference_migration.dart';
import 'package:isar/isar.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/providers/isar_provider.dart';
import '../../../../core/services/private_storage_service.dart';
import '../../data/services/external_storage_service.dart';
import '../../data/services/reference_migration_service.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/collection.dart';

final referenceMigrationServiceProvider =
    FutureProvider<ReferenceMigrationService>((ref) async {
      final isar = await ref.watch(isarProvider.future);
      final storage = await ref.watch(externalStorageServiceProvider.future);
      return ReferenceMigrationService(
        isar,
        await getPrivateStorageDirectory(),
        beforeStart: () async {
          final report = await ref
              .read(operationJournalServiceProvider)
              .readReport();
          if (report.entries.isNotEmpty || report.hasCorruption) {
            throw StateError('migration_recovery_pending');
          }
        },
        withSource: (locator, name, read) async {
          final raw = Uri.parse(locator);
          final uri = raw.hasScheme ? raw : Uri.file(locator);
          storage.activeImportGrants.add(uri);
          String? copied;
          try {
            copied = await storage.copyToTemp(uri, name);
            if (copied == null) {
              throw const FileSystemException('migration_source_unavailable');
            }
            await read(File(copied));
          } finally {
            storage.activeImportGrants.remove(uri);
            // copyToTemp may lend the original file. Only own external_view copies.
            final temporary = await getTemporaryDirectory();
            if (copied != null &&
                p.isWithin(p.join(temporary.path, 'external_view'), copied) &&
                !(uri.isScheme('file') && p.equals(uri.toFilePath(), copied))) {
              final file = File(copied);
              if (await file.exists()) await file.delete();
            }
          }
        },
        releaseAccess: storage.releasePersistedAccess,
      );
    });

final referenceMigrationInventoryProvider =
    FutureProvider.autoDispose<List<ReferenceMigrationGroup>>((ref) async {
      final service = await ref.watch(referenceMigrationServiceProvider.future);
      if (!ref.mounted) return const [];
      final items = service.isar.mediaItems.watchLazy().listen(
        (_) => ref.invalidateSelf(),
      );
      final cols = service.isar.mediaCollections.watchLazy().listen(
        (_) => ref.invalidateSelf(),
      );
      ref.onDispose(() {
        items.cancel();
        cols.cancel();
      });
      return service.inventory();
    });

final referenceMigrationNeedsAttentionProvider =
    FutureProvider.autoDispose<bool>((ref) async {
      final service = await ref.watch(referenceMigrationServiceProvider.future);
      if (!ref.mounted) return false;
      final pending = service.isar.referenceMigrations.watchLazy().listen(
        (_) => ref.invalidateSelf(),
      );
      ref.onDispose(pending.cancel);
      final groups = await ref.watch(
        referenceMigrationInventoryProvider.future,
      );
      if (!ref.mounted) return false;
      if (groups.isNotEmpty) return true;
      return (await service.isar.referenceMigrations.where().findAll()).any(
        (r) => r.cleanupPending,
      );
    });
