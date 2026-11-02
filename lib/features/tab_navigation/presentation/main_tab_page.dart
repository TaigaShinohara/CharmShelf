import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';
import '../../../core/feedback/feedback_providers.dart';
import '../../../core/providers/tab_navigation_provider.dart';
import '../../../core/providers/back_navigation_provider.dart';
import '../../../core/providers/unsaved_data_provider.dart';
import '../../../features/home/presentation/home_page.dart';
import '../../../features/library/presentation/providers/media_filter_provider.dart';
import '../../../features/library/presentation/screens/library_screen.dart';
import '../../../features/settings/presentation/providers/app_mode_provider.dart';
// import '../../../features/settings/presentation/settings_page.dart'; // Removed
import '../../../shared/widgets/dialogs/unsaved_data_dialog.dart';
import '../../../shared/widgets/navigation/app_bottom_navigation.dart';
import '../../../shared/widgets/navigation/bottom_navigation_style.dart';
import '../../../shared/widgets/navigation/liquid_glass_navigation.dart';
import '../../../shared/widgets/navigation/mini_player.dart';
import '../../../shared/widgets/navigation/swipable_player_overlay.dart';
import '../../library/presentation/providers/player_notifier.dart';

/// メインタブページ
///
/// 各タブは独立したナビゲーションスタックを持ち、
/// 同じタブを再タップするとルート画面に戻ります。
/// 未保存データがある場合は確認ダイアログを表示します。
class MainTabPage extends ConsumerStatefulWidget {
  const MainTabPage({super.key});

  @override
  ConsumerState<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends ConsumerState<MainTabPage> {
  /// 各タブのNavigator用GlobalKey
  late final List<GlobalKey<NavigatorState>> _navigatorKeys;
  late final List<_NavigationHapticsObserver> _navigationObservers;
  DateTime? _lastBackHandledAt;
  static const Duration _backHandlingCooldown = Duration(milliseconds: 120);

  bool _shouldIgnoreBackAction() {
    final now = DateTime.now();
    final lastHandledAt = _lastBackHandledAt;
    if (lastHandledAt != null &&
        now.difference(lastHandledAt) < _backHandlingCooldown) {
      return true;
    }
    _lastBackHandledAt = now;
    return false;
  }

  @override
  void initState() {
    super.initState();

    // 各タブ用のNavigatorKeyを生成 (Library, Home)
    _navigatorKeys = [GlobalKey<NavigatorState>(), GlobalKey<NavigatorState>()];
    _navigationObservers = List.generate(
      _navigatorKeys.length,
      (_) => _NavigationHapticsObserver(ref),
    );

    // オンボーディング直後は必ずライブラリを優先する。それ以外の
    // コールドスタートでは、ユーザーが最後に使ったタブを復元する。
    if (ref.read(pendingLibraryLaunchActionProvider) == null) {
      unawaited(
        ref.read(currentTabIndexProvider.notifier).restoreLastSelectedTab(),
      );
    }
  }

  /// タブがタップされたときの処理
  Future<void> _onTabTapped(int index) async {
    final currentIndex = ref.read(currentTabIndexProvider);
    if (index == currentIndex) {
      // 同じタブが再タップされた場合
      await _handleSameTabTapped(index);
    } else {
      // 異なるタブがタップされた場合
      // 未保存データがある場合は確認ダイアログを表示
      if (hasUnsavedData(ref)) {
        final shouldDiscard = await showUnsavedDataDialog(context);
        if (!shouldDiscard) {
          return;
        }
        ref.read(unsavedDataKeysProvider.notifier).clearAll();
      }

      _triggerTabSelectionHaptics();
      ref.read(currentTabIndexProvider.notifier).switchTo(index);
    }
  }

  /// 同じタブが再タップされたときの処理
  ///
  /// 未保存データがある場合は確認ダイアログを表示し、
  /// ユーザーが許可した場合のみルートに戻ります。
  Future<void> _handleSameTabTapped(int index) async {
    final navigatorKey = _navigatorKeys[index];
    final navigatorState = navigatorKey.currentState;

    if (navigatorState == null) return;

    final libraryMode = index == 0 ? ref.read(appModeProvider) : null;
    final libraryFolderPath = libraryMode == null
        ? null
        : ref.read(mediaFilterNotifierProvider(libraryMode)).parentPath;

    // 別画面とライブラリ内のフォルダ階層の両方を確認する
    if (!navigatorState.canPop() && libraryFolderPath == null) {
      // すでにルート画面なので何もしない
      return;
    }

    // 未保存データがあるかチェック
    if (hasUnsavedData(ref)) {
      final shouldDiscard = await showUnsavedDataDialog(context);
      if (!shouldDiscard) {
        // ユーザーがキャンセルした場合は何もしない
        return;
      }
      // 未保存データをクリア
      ref.read(unsavedDataKeysProvider.notifier).clearAll();
    }

    // ルートまで戻る
    _triggerTabSelectionHaptics();
    // 同一タブ再タップ時のpopUntilでは、didPopでのハプティクスを抑制する
    // （タブ選択のselection hapticsと二重にならないように）
    _navigationObservers[index].suppressPopHapticsWhile(
      () => navigatorState.popUntil((route) => route.isFirst),
    );
    if (libraryFolderPath != null) {
      ref
          .read(mediaFilterNotifierProvider(libraryMode!).notifier)
          .updateParentPath(null);
    }
  }

  /// 戻るボタン（Android）の処理
  Future<bool> _onWillPop() async {
    final currentIndex = ref.read(currentTabIndexProvider);
    final navigatorKey = _navigatorKeys[currentIndex];
    final navigatorState = navigatorKey.currentState;

    if (navigatorState != null) {
      final hadNestedRoute = navigatorState.canPop();
      final revisionBefore = ref.read(backNavigationRevisionProvider);
      final didPop = await navigatorState.maybePop();
      final rootStateHandled =
          ref.read(backNavigationRevisionProvider) != revisionBefore;
      if (hadNestedRoute || didPop || rootStateHandled) {
        return false;
      }
    }

    // ライブラリタブの場合、InternalLibraryScreen / ExternalLibraryScreen 側で
    // PopScope を設定し、階層移動が必要な場合は canPop: false としてシステムバックをブロック、
    // 戻る処理を行うようになっている。
    // そのため、MainTabPage までポップイベントが到達した場合は、
    // 「ライブラリ画面はルート階層にいる（戻る必要がない）」状態である。
    return true;
  }

  void _triggerTabSelectionHaptics() {
    unawaited(ref.read(feedbackServiceProvider).selection());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final items = [
      TabItem(
        label: l10n.libraryTitle,
        icon: Icons.library_books_outlined,
        selectedIcon: Icons.library_books,
        page: const LibraryScreen(),
        navigatorKey: _navigatorKeys[0],
      ),
      TabItem(
        label: l10n.homeTitle,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        page: Consumer(
          builder: (context, ref, child) {
            final mode = ref.watch(appModeProvider);
            return HomePage(key: ValueKey('home-${mode.name}'));
          },
        ),
        navigatorKey: _navigatorKeys[1],
      ),
    ];

    return PopScope(
      // Android: 常にカスタムロジックで戻る操作を制御する（ルート階層での終了は行わない）
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_shouldIgnoreBackAction()) return;

        // 1. ルートNavigator上にモーダル（ボトムシート、ダイアログ等）が開いていれば最優先で閉じる
        final rootNav = Navigator.maybeOf(context, rootNavigator: true);
        if (rootNav != null && rootNav.canPop()) {
          final didPopRoot = await rootNav.maybePop();
          if (didPopRoot) {
            return;
          }
        }

        // 2. プレイヤー展開中なら縮小
        final playerState = ref.read(playerNotifierProvider);
        if (playerState.currentItem != null && playerState.isExpanded) {
          ref.read(playerNotifierProvider.notifier).collapse();
          return;
        }

        // 3. タブ内ナビゲーション（ネストされた画面やフォルダ移動）を処理
        final shouldExit = await _onWillPop();
        if (!shouldExit) {
          return;
        }

        if (!context.mounted) return;

        // 4. タブ内スタックがルート階層の場合、GoRouterのスタックをチェック
        final router = GoRouter.maybeOf(context);
        if (router != null && router.canPop()) {
          router.pop();
          return;
        }

        // 5. Androidの開始地点では標準のBack規約に従ってランチャーへ戻る。
        await SystemNavigator.pop();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final currentIndex = ref.watch(currentTabIndexProvider);
                      return IndexedStack(
                        index: currentIndex,
                        children: [
                          for (int i = 0; i < items.length; i++)
                            _TabNavigator(
                              navigatorKey: _navigatorKeys[i],
                              rootPage: items[i].page,
                              observers: [_navigationObservers[i]],
                            ),
                        ],
                      );
                    },
                  ),
                ),
                // 下部の余白（ミニプレイヤーとタブバーが重ならないように）
                // プレイヤーが表示されている時のみ、その高さ分の余白を確保
                Consumer(
                  builder: (context, ref, child) {
                    final playerState = ref.watch(playerNotifierProvider);
                    final showMini =
                        playerState.currentItem != null &&
                        playerState.showMiniPlayer;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      height: showMini ? MiniPlayer.height : 0,
                    );
                  },
                ),
              ],
            ),
            // YouTube風スワイププレイヤー
            const SwipablePlayerOverlay(),
          ],
        ),
        bottomNavigationBar: Consumer(
          builder: (context, ref, child) {
            final isPlayerExpanded = ref.watch(
              playerNotifierProvider.select((s) => s.isExpanded),
            );
            // プレイヤー展開時はナビバーを非表示にして全画面表示にする
            if (isPlayerExpanded) {
              return const SizedBox.shrink();
            }
            final currentIndex = ref.watch(currentTabIndexProvider);
            return _BottomNav(
              currentIndex: currentIndex,
              items: items,
              onTap: _onTabTapped,
            );
          },
        ),
      ),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<TabItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(bottomNavigationStyleNotifierProvider);
    return switch (style) {
      BottomNavigationStyle.simple => AppBottomNavigation(
        currentIndex: currentIndex,
        items: items,
        onTap: onTap,
      ),
      BottomNavigationStyle.liquidGlass => LiquidGlassNavigation(
        currentIndex: currentIndex,
        items: items,
        onTap: onTap,
      ),
    };
  }
}

/// 各タブ用のNavigatorラッパー
///
/// タブごとに独立したナビゲーションスタックを管理します。
class _TabNavigator extends StatelessWidget {
  const _TabNavigator({
    required this.navigatorKey,
    required this.rootPage,
    required this.observers,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget rootPage;
  final List<NavigatorObserver> observers;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      observers: observers,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => rootPage,
          settings: settings,
        );
      },
    );
  }
}

class _NavigationHapticsObserver extends NavigatorObserver {
  _NavigationHapticsObserver(this._ref);

  final WidgetRef _ref;
  bool _suppressPopHaptics = false;

  void suppressPopHapticsWhile(VoidCallback action) {
    _suppressPopHaptics = true;
    action();
    _suppressPopHaptics = false;
  }

  void _triggerNavigationHaptics() {
    unawaited(_ref.read(feedbackServiceProvider).lightImpact());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _triggerNavigationHaptics();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_suppressPopHaptics) return;
    _triggerNavigationHaptics();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _triggerNavigationHaptics();
  }
}
