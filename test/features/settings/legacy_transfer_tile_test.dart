import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/core/preferences/app_preferences.dart';
import 'package:private_shelf/features/library/data/services/legacy_migration_service.dart';
import 'package:private_shelf/features/library/presentation/providers/legacy_migration_provider.dart';
import 'package:private_shelf/features/settings/presentation/widgets/tiles/legacy_transfer_tile.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class _Service extends Mock implements LegacyMigrationService {}

void main() {
  testWidgets(
    'settings opens the optional route; deferring returns and permits reopening',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = _Service();
      when(() => service.load()).thenAnswer((_) async => null);
      final container = ProviderContainer(
        overrides: [
          hapticsEnabledProvider.overrideWith((ref) => false),
          legacyMigrationServiceProvider.overrideWith((ref) async => service),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: LegacyTransferTile()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(
          find.byKey(const ValueKey('settings-legacy-transfer')),
        );
        await tester.pumpAndSettle();
        expect(container.read(legacyScreenOpenProvider), isTrue);
        expect(find.text('フォルダを選ぶ'), findsOneWidget);
        expect(find.text('アクセスを許可する'), findsNothing);
        await tester.tap(find.text('あとで'));
        await tester.pumpAndSettle();
        expect(container.read(legacyScreenOpenProvider), isFalse);
        expect(
          find.byKey(const ValueKey('settings-legacy-transfer')),
          findsOneWidget,
        );
      }
      expect(
        (await SharedPreferences.getInstance()).getString(
          AppPreferences.legacyEntryChoiceKey,
        ),
        'later',
      );
      verifyNever(() => service.execute(restore: true));
      verifyNever(() => service.execute(restore: false));
    },
  );
}
