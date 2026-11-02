import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:private_shelf/core/providers/isar_provider.dart';
import 'package:private_shelf/features/library/data/services/library_database_integrity_service.dart';

final libraryDatabaseIntegrityServiceProvider =
    FutureProvider<LibraryDatabaseIntegrityService>((ref) async {
      final isar = await ref.watch(isarProvider.future);
      return LibraryDatabaseIntegrityService(isar);
    });
