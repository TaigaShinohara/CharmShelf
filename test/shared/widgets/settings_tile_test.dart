import '../finders.dart' as shared_find;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/shared/widgets/settings/settings_tile.dart';
import 'package:private_shelf/shared/widgets/settings/settings_switch_tile.dart';
import 'package:private_shelf/shared/widgets/settings/settings_section.dart';

void main() {
  group('SettingsTile', () {
    testWidgets('アイコン、タイトル、サブタイトルが表示される', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SettingsTile(
                icon: Icons.settings,
                title: 'Test Title',
                subtitle: 'Test Subtitle',
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Subtitle'), findsOneWidget);
    });

    for (final title in ['言語設定', 'Language']) {
      testWidgets('320dp・200%でも項目名の幅を保ち値と操作を表示する: $title', (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var tapped = false;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SettingsTile(
                    icon: Icons.language,
                    title: title,
                    value: 'System settings',
                    onTap: () => tapped = true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final titleFinder = shared_find.findAppText(title);
        final valueFinder = shared_find.findAppText('System settings');
        expect(tester.getSize(titleFinder).width, greaterThanOrEqualTo(140));
        expect(
          tester.getTopLeft(valueFinder).dy,
          greaterThan(tester.getBottomLeft(titleFinder).dy),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(titleFinder);
        expect(tapped, isTrue);
      });
    }

    testWidgets('サブタイトルなしで表示できる', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SettingsTile(icon: Icons.info, title: 'Only Title'),
            ),
          ),
        ),
      );

      expect(find.text('Only Title'), findsOneWidget);
    });

    testWidgets('タップするとonTapが呼ばれる', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SettingsTile(
                icon: Icons.tap_and_play,
                title: 'Tappable',
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tappable'));
      expect(tapped, true);
    });

    testWidgets('onTapがnullの場合はタップしても何も起きない', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SettingsTile(icon: Icons.block, title: 'Not Tappable'),
            ),
          ),
        ),
      );

      // タップしてもエラーが発生しないことを確認
      await tester.tap(find.text('Not Tappable'));
      await tester.pump();
    });
  });

  group('SettingsSwitchTile', () {
    testWidgets('スイッチが表示される', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SettingsSwitchTile(
                icon: Icons.toggle_on,
                title: 'Toggle Option',
                value: true,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('valueがtrueの場合スイッチがONになる', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SettingsSwitchTile(
                icon: Icons.toggle_on,
                title: 'ON Switch',
                value: true,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, true);
    });

    testWidgets('valueがfalseの場合スイッチがOFFになる', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SettingsSwitchTile(
                icon: Icons.toggle_off,
                title: 'OFF Switch',
                value: false,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, false);
    });

    testWidgets('スイッチを切り替えるとonChangedが呼ばれる', (tester) async {
      bool? receivedValue;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SettingsSwitchTile(
                icon: Icons.toggle_on,
                title: 'Changeable',
                value: false,
                onChanged: (v) => receivedValue = v,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      expect(receivedValue, true);
    });
  });

  group('SettingsSection', () {
    testWidgets('タイトルと子要素が表示される', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsSection(
              title: 'Section Title',
              children: [
                ListTile(title: Text('Item 1')),
                ListTile(title: Text('Item 2')),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Section Title'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('空の子要素でもエラーにならない', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsSection(title: 'Empty Section', children: []),
          ),
        ),
      );

      expect(find.text('Empty Section'), findsNothing);
    });
  });
}
