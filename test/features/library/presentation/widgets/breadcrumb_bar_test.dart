import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/presentation/widgets/breadcrumb_bar.dart';

import '../../../../helpers/test_helpers.dart';

void main() {
  testWidgets('ルートと中間階層へ移動でき、現在階層は操作しない', (tester) async {
    String? selectedPath = 'not-called';

    await tester.pumpWidget(
      createProviderApp(
        Scaffold(
          body: BreadcrumbBar(
            currentPath: 'library/parent/current',
            rootLabel: 'ライブラリ',
            physicalPath: '/documents/library/parent/current',
            onPathSelected: (path) => selectedPath = path,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('parent'));
    expect(selectedPath, 'library/parent');

    await tester.tap(find.byKey(const ValueKey('breadcrumb-root')));
    expect(selectedPath, isNull);

    selectedPath = 'not-called';
    await tester.tap(find.text('current'));
    expect(selectedPath, 'not-called');

    final siblingMenu = find.byTooltip('currentと同じ階層のフォルダを表示');
    expect(siblingMenu, findsOneWidget);
    final siblingButtonSize = tester.getSize(
      find.ancestor(of: siblingMenu, matching: find.byType(IconButton)),
    );
    expect(siblingButtonSize.width, greaterThanOrEqualTo(48));
    expect(siblingButtonSize.height, greaterThanOrEqualTo(48));
  });

  testWidgets('階層移動の意味とヒントをセマンティクスへ公開する', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      createProviderApp(
        Scaffold(
          body: BreadcrumbBar(
            currentPath: 'library/current',
            rootLabel: 'ライブラリ',
            onPathSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('ライブラリ、ルート'), findsOneWidget);
    // 内部ストレージの 'library' プレフィックスはルートに包含されるため、個別の 'library' セグメントは存在しない
    expect(find.bySemanticsLabel('library'), findsNothing);
    expect(find.bySemanticsLabel('current'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('内部ストレージのlibraryルートのみの場合はルートセグメントのみ表示される', (tester) async {
    await tester.pumpWidget(
      createProviderApp(
        Scaffold(
          body: BreadcrumbBar(
            currentPath: 'library',
            rootLabel: '内部ストレージ',
            onPathSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('内部ストレージ'), findsOneWidget);
    expect(find.text('library'), findsNothing);
  });

  testWidgets('狭い画面の子階層でもルート操作を画面内へ固定する', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createProviderApp(
        Scaffold(
          body: BreadcrumbBar(
            currentPath: 'library/レビュー用フォルダ',
            rootLabel: '内部ストレージ',
            physicalPath: '/documents/library/レビュー用フォルダ',
            onPathSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rootRect = tester.getRect(
      find.byKey(const ValueKey('breadcrumb-root')),
    );
    expect(rootRect.left, greaterThanOrEqualTo(0));
    expect(rootRect.right, lessThanOrEqualTo(320));
    expect(rootRect.width, greaterThanOrEqualTo(48));
    expect(find.text('レビュー用フォルダ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('絵文字やサロゲートペアを含む長文フォルダ名を安全に省略表示できる', (tester) async {
    // 17文字以上の絵文字入りフォルダ名
    const longEmojiFolder = '📁とても大切な思い出の写真アルバム2026🎉✨';

    await tester.pumpWidget(
      createProviderApp(
        Scaffold(
          body: BreadcrumbBar(
            currentPath: 'library/$longEmojiFolder',
            rootLabel: 'ライブラリ',
            onPathSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // クラッシュせず正常に描画されることを確認
    expect(find.byType(BreadcrumbBar), findsOneWidget);
    expect(find.text('library'), findsNothing);
  });
}
