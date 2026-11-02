import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../../../core/providers/isar_provider.dart';
import '../../../../core/providers/shared_preferences_provider.dart';
import '../../../library/domain/models/media_item.dart';
import '../../../library/presentation/providers/import_flow_provider.dart';

class PersonalLibraryState {
  const PersonalLibraryState({
    required this.hasImported,
    this.guideDismissed = false,
  });
  final bool hasImported;
  final bool guideDismissed;
  bool get showFirstImportGuide => !hasImported && !guideDismissed;
}

const personalImportCompletedKey = 'personal_import_completed_v1';
const personalImportGuideDismissedKey = 'personal_import_guide_dismissed_v1';

final personalLibraryStateProvider =
    StreamProvider.autoDispose<PersonalLibraryState>((ref) async* {
      final flow = ref.watch(importFlowNotifierProvider);
      final prefs = await ref.watch(sharedPreferencesProvider.future);
      if (!ref.mounted) return;
      final isar = await ref.watch(isarProvider.future);
      if (!ref.mounted) return;
      final query = isar.mediaItems
          .filter()
          .typeEqualTo(MediaType.file)
          .isTrashedEqualTo(false)
          .not()
          .originalPathStartsWith('template://welcome/')
          .build();
      await for (final _ in query.watchLazy(fireImmediately: true)) {
        var completed = prefs.getBool(personalImportCompletedKey) ?? false;
        // Import transactions may still be rolled back until their final outcome.
        if (!completed && flow.status != ImportFlowStatus.importing) {
          completed =
              flow.importReport?.hasCommittedFiles == true ||
              await query.count() > 0;
          if (completed) {
            try {
              await prefs.setBool(personalImportCompletedKey, true);
            } catch (_) {
              // The retained data remains the source of truth on the next load.
            }
          }
        }
        yield PersonalLibraryState(
          hasImported: completed,
          guideDismissed:
              prefs.getBool(personalImportGuideDismissedKey) ?? false,
        );
      }
    });

Future<void> dismissPersonalImportGuide(WidgetRef ref) async {
  final prefs = await ref.read(sharedPreferencesProvider.future);
  await prefs.setBool(personalImportGuideDismissedKey, true);
  ref.invalidate(personalLibraryStateProvider);
}
