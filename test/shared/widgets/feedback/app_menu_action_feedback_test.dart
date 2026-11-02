import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/shared/widgets/feedback/app_menu_action_feedback.dart';

void main() {
  testWidgets('押すと約1秒チェックへ切り替わり、連打せず元のアイコンへ戻る', (tester) async {
    var callCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppMenuActionFeedback(
            icon: Icons.copy_outlined,
            onPressed: () => callCount++,
            builder: (context, icon, onPressed) =>
                IconButton(onPressed: onPressed, icon: icon),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.tap(find.byType(IconButton));
    await tester.pump(const Duration(milliseconds: 225));

    final rotation = tester.widget<RotationTransition>(
      find
          .descendant(
            of: find.byType(AppMenuActionFeedback),
            matching: find.byType(RotationTransition),
          )
          .first,
    );
    expect(rotation.turns.value, greaterThan(0));
    expect(rotation.turns.value, lessThan(1));

    await tester.pump(const Duration(milliseconds: 225));

    expect(callCount, 1);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 140));

    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
  });

  testWidgets('完了後処理はチェック表示が終わってから1回だけ実行する', (tester) async {
    var pressedCount = 0;
    var completedCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppMenuActionFeedback(
            icon: Icons.tune,
            onPressed: () => pressedCount++,
            onFeedbackComplete: () => completedCount++,
            builder: (context, icon, onPressed) =>
                IconButton(onPressed: onPressed, icon: icon),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    expect(pressedCount, 1);
    expect(completedCount, 0);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 999));
    expect(completedCount, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(completedCount, 1);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
