import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:private_shelf/features/library/data/services/reference_migration_service.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/reference_migration_provider.dart';
import 'package:private_shelf/features/library/presentation/screens/reference_migration_screen.dart';
import 'package:private_shelf/features/settings/domain/models/privacy_settings.dart';
import 'package:private_shelf/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class _Database extends Mock implements Isar {}

class _Privacy extends PrivacySettingsNotifier {
  @override
  Future<PrivacySettings> build() async => const PrivacySettings();
}

class _Service extends ReferenceMigrationService {
  _Service()
    : super(
        _Database(),
        Directory('/unused'),
        withSource: (_, _, _) async {},
        releaseAccess: (_) async {},
      );
  int copies = 0;
  @override
  Future<void> migrate(
    ReferenceMigrationGroup group, {
    void Function(int, int)? onProgress,
  }) async {
    copies++;
  }
}

void main() {
  for (final locale in ['ja', 'en']) {
    testWidgets(
      '$locale migration requires confirmation and fits 320dp/200% text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = _Service();
        final group = ReferenceMigrationGroup([
          MediaItem()
            ..id = 1
            ..path = 'content://test/document/file'
            ..originalPath = 'test.txt'
            ..sourceType = MediaSourceType.externalReference,
        ], []);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              privacySettingsNotifierProvider.overrideWith(_Privacy.new),
              referenceMigrationServiceProvider.overrideWith(
                (_) async => service,
              ),
              referenceMigrationInventoryProvider.overrideWith(
                (_) async => [group],
              ),
            ],
            child: MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const ReferenceMigrationScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(service.copies, 0);
        expect(tester.takeException(), isNull);
        final context = tester.element(find.byType(ReferenceMigrationScreen));
        final l = AppLocalizations.of(context)!;
        final button = find.widgetWithText(
          FilledButton,
          l.referenceMigrationCopy,
        );
        await tester.scrollUntilVisible(
          button,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        while (tester.getCenter(button).dy > 650) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -180),
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(service.copies, 0);
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text(l.commonCancel));
        await tester.pumpAndSettle();
        expect(service.copies, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
