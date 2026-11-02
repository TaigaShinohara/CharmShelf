import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/providers/path_provider.dart';
import 'package:private_shelf/features/library/domain/models/media_item.dart';
import 'package:private_shelf/features/library/presentation/providers/player_notifier.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import 'package:private_shelf/shared/widgets/navigation/mini_player.dart';

class _MockPlayerNotifier extends PlayerNotifier {
  _MockPlayerNotifier(this._initialState);

  final PlayerState _initialState;

  bool pauseCalled = false;
  bool resumeCalled = false;
  bool stopCalled = false;
  bool expandCalled = false;

  @override
  PlayerState build() => _initialState;

  @override
  Future<void> pause() async {
    pauseCalled = true;
    state = state.copyWith(isPlaying: false);
  }

  @override
  Future<void> resume() async {
    resumeCalled = true;
    state = state.copyWith(isPlaying: true);
  }

  @override
  Future<void> stop({Object? owner}) async {
    stopCalled = true;
    state = PlayerState();
  }

  @override
  void expand() {
    expandCalled = true;
  }
}

void main() {
  testWidgets('MiniPlayer はアイテムが存在しない場合 SizedBox.shrink を返す', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('ja'),
          home: Scaffold(body: MiniPlayer()),
        ),
      ),
    );

    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('MiniPlayer はタイトルを表示し、再生/一時停止/閉じる/展開が正常に動作する', (tester) async {
    final item = MediaItem()
      ..id = 1
      ..path = 'audios/sample_track.mp3'
      ..type = MediaType.file;

    final mockNotifier = _MockPlayerNotifier(
      PlayerState(currentItem: item, isPlaying: true),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerNotifierProvider.overrideWith(() => mockNotifier),
          appDocumentsPathSyncProvider.overrideWithValue('/tmp'),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('ja'),
          home: Scaffold(body: MiniPlayer()),
        ),
      ),
    );

    expect(find.text('sample track'), findsOneWidget);

    // ミニプレイヤー本体をタップして展開
    await tester.tap(find.text('sample track'));
    await tester.pump();
    expect(mockNotifier.expandCalled, isTrue);

    // 一時停止ボタンをタップ
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(mockNotifier.pauseCalled, isTrue);

    // 閉じるボタンをタップ
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(mockNotifier.stopCalled, isTrue);
  });

  testWidgets('MiniPlayer はエラー時にエラーテキストを表示する', (tester) async {
    final item = MediaItem()
      ..id = 2
      ..path = 'videos/corrupted.mp4'
      ..type = MediaType.file;

    final mockNotifier = _MockPlayerNotifier(
      PlayerState(currentItem: item, error: 'デコード失敗', isPlaying: false),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerNotifierProvider.overrideWith(() => mockNotifier),
          appDocumentsPathSyncProvider.overrideWithValue('/tmp'),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('ja'),
          home: Scaffold(body: MiniPlayer()),
        ),
      ),
    );

    expect(find.text('再生エラー: デコード失敗'), findsOneWidget);
  });
}
