import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/preferences/app_preferences.dart';
import '../../../../../core/providers/shared_preferences_provider.dart';
import '../../../../../features/library/presentation/providers/legacy_migration_provider.dart';
import '../../../../../features/library/presentation/screens/legacy_migration_screen.dart';
import '../../../../../features/library/data/services/legacy_migration_service.dart';
import '../../../../../gen_l10n/app_localizations.dart';
import '../../../../../shared/widgets/settings/settings_tile.dart';

class LegacyTransferTile extends ConsumerWidget {
  const LegacyTransferTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final status = ref.watch(legacyMigrationRecordProvider);
    final record = status.asData?.value;
    final subtitle = status.hasError
        ? l.legacyRecordFailure
        : record?.requiresRecovery == true
        ? l.legacyRecoveryTitle
        : record?.phase == LegacyPhase.choice
        ? l.legacyFoundTitle
        : record?.phase == LegacyPhase.complete
        ? switch (record!.completedOutcome) {
            LegacyOutcome.notFound => l.legacyNotFoundTitle,
            LegacyOutcome.restored => l.legacyRestoredTitle,
            LegacyOutcome.deleted => l.legacyDeletedTitle,
          }
        : l.legacyReturningHint;
    return SettingsTile(
      key: const ValueKey('settings-legacy-transfer'),
      icon: Icons.restore,
      trailing: const Icon(Icons.chevron_right),
      title: l.legacyTransferTitle,
      subtitle: subtitle,
      onTap: () async {
        if (ref.read(legacyScreenOpenProvider)) return;
        ref.read(legacyScreenOpenProvider.notifier).state = true;
        try {
          await Navigator.of(context, rootNavigator: true).push<void>(
            MaterialPageRoute(
              builder: (routeContext) => LegacyMigrationScreen(
                fromSettings: true,
                onCompleted: () {
                  Navigator.of(routeContext).pop();
                },
                onDeferred: () async {
                  final prefs = await ref.read(
                    sharedPreferencesProvider.future,
                  );
                  if (!await prefs.setString(
                    AppPreferences.legacyEntryChoiceKey,
                    'later',
                  )) {
                    throw StateError('Could not save deferred transfer');
                  }
                  if (routeContext.mounted) Navigator.of(routeContext).pop();
                },
              ),
            ),
          );
        } finally {
          ref.invalidate(legacyMigrationRecordProvider);
          ref.read(legacyScreenOpenProvider.notifier).state = false;
        }
      },
    );
  }
}
