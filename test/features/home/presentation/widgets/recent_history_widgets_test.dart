import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/features/home/presentation/widgets/recent_history_widgets.dart';

final _scope = StateProvider((ref) => false);
final _history = StreamProvider.autoDispose<List<String>>((ref) async* {
  ref.watch(_scope);
  yield const [];
});
final _all = StreamProvider.autoDispose<List<String>>((ref) async* {
  yield List.generate(20, (i) => 'File $i');
});

Widget _app(ProviderContainer container, {double scale = 1}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecentHistorySection<String>(
              title: 'Recent files',
              icon: const Icon(Icons.history),
              provider: _history,
              listProvider: _all,
              itemBuilder: (_, title) => RecentHistoryCard(
                title: title,
                subtitle: 'Shelf',
                metadata: 'PNG',
                preview: const ColoredBox(color: Colors.blue),
                onTap: () {},
                onActions: () {},
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('home shows four entries and list shows twenty, then returns', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        _history.overrideWith(
          (ref) => Stream.value(List.generate(5, (i) => 'File $i')),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    expect(find.byType(RecentHistoryCard), findsNWidgets(4));
    await tester.tap(find.text('See more'));
    await tester.pumpAndSettle();
    expect(find.byType(RecentHistoryCard), findsNWidgets(20));
    await tester.ensureVisible(find.text('File 19'));
    expect(find.text('File 19').hitTestable(), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(RecentHistoryCard), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scope reload removes previous private entries immediately', (
    tester,
  ) async {
    final next = StreamController<List<String>>();
    addTearDown(next.close);
    final container = ProviderContainer(
      overrides: [
        _history.overrideWith((ref) {
          return ref.watch(_scope)
              ? next.stream
              : Stream.value(['Private file']);
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    expect(find.text('Private file'), findsOneWidget);
    container.read(_scope.notifier).state = true;
    await tester.pump();
    expect(find.text('Private file'), findsNothing);
    next.add([]);
    await tester.pumpAndSettle();
    expect(find.text('Recent files'), findsNothing);
  });

  testWidgets('failed history can retry and become an empty section', (
    tester,
  ) async {
    var attempts = 0;
    final container = ProviderContainer(
      overrides: [
        _history.overrideWith((ref) {
          attempts++;
          return attempts == 1
              ? Stream.error(StateError('test failure'))
              : Stream.value([]);
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    expect(find.text('Recent files'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Recent files'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a single recent entry uses the full width without a giant image',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [
          _history.overrideWith((ref) => Stream.value(['A recent picture'])),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();
      final card = tester.getRect(find.byType(RecentHistoryCard));
      expect(card.width, 358);
      expect(card.height, 128);
      expect(card.left, 16);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a full-width card preserves names and controls at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        _history.overrideWith((ref) => Stream.value(['家族と出かけた春の旅のとても長い写真の名前'])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container, scale: 2));
    await tester.pumpAndSettle();
    expect(find.text('PNG').hitTestable(), findsOneWidget);
    expect(find.byType(IconButton).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 800.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('cards fit width $width and text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            _history.overrideWith(
              (ref) => Stream.value(
                List.generate(4, (i) => '長い名前のファイルと棚を識別するための資料 $i.pdf'),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(_app(container, scale: scale));
        await tester.pumpAndSettle();
        final cards = find.byType(RecentHistoryCard);
        final first = tester.getRect(cards.first);
        final second = tester.getRect(cards.at(1));
        if (width == 320 || (scale == 2 && width < 400)) {
          expect(second.top, greaterThan(first.bottom));
        } else {
          expect(second.top, first.top);
        }
        for (var i = 0; i < 4; i++) {
          final rect = tester.getRect(cards.at(i));
          expect(rect.left, greaterThanOrEqualTo(16));
          expect(rect.right, lessThanOrEqualTo(width - 16));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('tap, long press and menu use separate accessible controls', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    var opens = 0;
    var actions = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 250,
            child: RecentHistoryCard(
              title: 'File',
              subtitle: 'Shelf',
              preview: const SizedBox(),
              onTap: () => opens++,
              onActions: () => actions++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(InkWell).first);
    await tester.longPress(find.byType(InkWell).first);
    await tester.tap(find.byType(IconButton));
    expect(opens, 1);
    expect(actions, 2);
    expect(find.bySemanticsLabel('File, Shelf'), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
