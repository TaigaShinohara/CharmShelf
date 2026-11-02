import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/presentation/widgets/library_mode_title.dart';

void main() {
  testWidgets('gradient title is painted directly without a ShaderMask', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: LibraryModeTitle(
                title: 'CharmShelf',
                titleGradient: LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ShaderMask), findsNothing);
    final title = tester.widget<Text>(find.text('CharmShelf'));
    expect(title.style?.shadows, isEmpty);
    expect(title.style?.foreground?.shader, isNotNull);
  });

  testWidgets('plain title has neither a shader nor shadows', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: LibraryModeTitle(title: 'CharmShelf')),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('CharmShelf'));
    expect(title.style?.shadows, isEmpty);
    expect(title.style?.foreground, isNull);
  });
}
