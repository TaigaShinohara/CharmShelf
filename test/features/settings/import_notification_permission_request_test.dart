import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:private_shelf/core/providers/shared_preferences_provider.dart';
import 'package:private_shelf/features/permission/data/repositories/permission_repository_impl.dart';
import 'package:private_shelf/features/permission/domain/repositories/permission_repository.dart';
import 'package:private_shelf/features/settings/presentation/widgets/tiles/import_notification_permission_tile.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/dialogs/dialog_actions.dart';

class _RequestDrivenPermissionRepository implements PermissionRepository {
  PermissionResult requestResult = PermissionResult.permanentlyDenied;
  PermissionResult status = PermissionResult.denied;
  int requestCalls = 0;
  int settingsCalls = 0;

  @override
  Future<PermissionResult> getNotificationPermissionStatus() async => status;

  @override
  Future<PermissionResult> requestNotificationPermission() async {
    requestCalls++;
    if (requestResult == PermissionResult.granted) {
      status = PermissionResult.granted;
    }
    return requestResult;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsCalls++;
    return true;
  }

  @override
  Future<PermissionResult> requestStoragePermission() async =>
      PermissionResult.denied;

  @override
  Future<PermissionResult> getManageStoragePermissionStatus() async =>
      PermissionResult.denied;

  @override
  Future<PermissionResult> requestManageStoragePermission() async =>
      PermissionResult.denied;
}

Future<void> _pumpTile(
  WidgetTester tester,
  _RequestDrivenPermissionRepository repository,
) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        permissionRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWith(
          (ref) async => SharedPreferences.getInstance(),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ImportNotificationPermissionTile()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('statusがdeniedでもrequestの恒久拒否結果からOS設定へ進める', (tester) async {
    final repository = _RequestDrivenPermissionRepository();
    await _pumpTile(tester, repository);

    await tester.tap(find.byType(ImportNotificationPermissionTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('通知を許可する'));
    await tester.pumpAndSettle();

    expect(repository.requestCalls, 1);
    expect(repository.settingsCalls, 0);
    expect(find.text('端末の設定を開く'), findsOneWidget);

    await tester.tap(find.text('端末の設定を開く'));
    await tester.pumpAndSettle();

    expect(repository.settingsCalls, 1);
    expect(repository.requestCalls, 1);
  });

  testWidgets('恒久拒否の設定誘導を閉じた後は過去結果を使わず再要求できる', (tester) async {
    final repository = _RequestDrivenPermissionRepository();
    await _pumpTile(tester, repository);

    await tester.tap(find.byType(ImportNotificationPermissionTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('通知を許可する'));
    await tester.pumpAndSettle();
    expect(find.text('端末の設定を開く'), findsOneWidget);

    // Closing the guidance must not retain permanent denial when Android's
    // subsequent status() returns denied, including "Ask every time".
    await tester.tap(find.byType(DialogCloseButton));
    await tester.pumpAndSettle();
    repository.requestResult = PermissionResult.granted;

    await tester.tap(find.byType(ImportNotificationPermissionTile));
    await tester.pumpAndSettle();
    expect(find.text('通知を許可する'), findsOneWidget);
    await tester.tap(find.text('通知を許可する'));
    await tester.pumpAndSettle();

    expect(repository.requestCalls, 2);
    expect(repository.settingsCalls, 0);
    await tester.pump(const Duration(seconds: 4));
  });
}
