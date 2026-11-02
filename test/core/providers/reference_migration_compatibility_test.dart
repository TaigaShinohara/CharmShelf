import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:private_shelf/features/library/data/services/reference_migration_service.dart';
import 'package:private_shelf/features/library/presentation/providers/reference_migration_provider.dart';

class _LateMigrationService extends Fake implements ReferenceMigrationService {
  int isarReads = 0;

  @override
  Isar get isar {
    isarReads++;
    throw StateError('disposed inventory must not open a database watch');
  }
}

void main() {
  test(
    'late migration service does not create watchers after disposal',
    () async {
      final pending = Completer<ReferenceMigrationService>();
      final service = _LateMigrationService();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          referenceMigrationServiceProvider.overrideWith(
            (ref) => pending.future,
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        referenceMigrationNeedsAttentionProvider,
        (_, _) {},
      );
      await container.pump();
      expect(
        container.exists(referenceMigrationNeedsAttentionProvider),
        isTrue,
      );
      subscription.close();
      await container.pump();
      expect(
        container.exists(referenceMigrationNeedsAttentionProvider),
        isFalse,
      );

      pending.complete(service);
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect(service.isarReads, 0);
    },
  );
}
