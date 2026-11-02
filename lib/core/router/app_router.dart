import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:go_router/go_router.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
// import 'package:private_shelf/features/library/presentation/screens/library_screen.dart'; // Unused
import 'package:private_shelf/features/library/domain/models/viewer_source_context.dart';
import 'package:private_shelf/features/library/presentation/screens/media_viewer_screen.dart';
import 'package:private_shelf/features/library/presentation/screens/tag_management_screen.dart';
import 'package:private_shelf/features/library/presentation/screens/archive_screen.dart';
import 'package:private_shelf/features/library/presentation/screens/trash_screen.dart';
import 'package:private_shelf/features/security/presentation/screens/passcode_screen.dart';
import 'package:private_shelf/features/security/presentation/providers/passcode_provider.dart';
import 'package:private_shelf/features/security/presentation/providers/security_guard_provider.dart';
import 'package:private_shelf/features/settings/presentation/privacy_settings_page.dart';
import 'package:private_shelf/features/settings/presentation/settings_page.dart';
import 'package:private_shelf/features/settings/presentation/info_page.dart';
import 'package:private_shelf/app/initialization_flow_screen.dart';

part 'app_router.g.dart';

/// ルーター設定（go_router）
@riverpod
GoRouter router(Ref ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen(
    securityGuardProvider,
    (previous, next) => refreshNotifier.refresh(),
  );

  final router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      // A parser callback captured before a scope reset must stay locked without
      // reading the previous scope's disposed Ref.
      final securityGuardState = ref.mounted
          ? ref.read(securityGuardProvider)
          : const AsyncData(false);
      final isUnlocked = securityGuardState.value ?? false;
      final isLocking = state.matchedLocation == '/passcode';
      final isInternalPasscodeFlow = state.extra is PasscodeRouteArgs;
      if (shouldKeepStartupSplashVisible(
        securityGuardState: securityGuardState,
        matchedLocation: state.matchedLocation,
      )) {
        return null;
      }
      if (securityGuardState.hasError) {
        // 判定失敗時は保護された起動エラー画面で再試行させる。
        return '/';
      }
      if (securityGuardState.isLoading) {
        if (isLocking) {
          return isInternalPasscodeFlow ? '/passcode' : null;
        }
        final currentUri = state.uri.toString();
        return currentUri != '/' && currentUri.isNotEmpty
            ? '/passcode?from=${Uri.encodeComponent(currentUri)}'
            : '/passcode';
      }
      if (!isUnlocked && isLocking && isInternalPasscodeFlow) {
        // 管理用フローは、ロック解除済みのアプリ内部から開始された場合だけ許可する。
        return '/passcode';
      }
      if (!isUnlocked && !isLocking) {
        final currentUri = state.uri.toString();
        if (currentUri != '/' &&
            currentUri != '/passcode' &&
            currentUri.isNotEmpty) {
          return '/passcode?from=${Uri.encodeComponent(currentUri)}';
        }
        return '/passcode';
      }
      if (isUnlocked && isLocking) {
        // URLだけでは設定・変更フローを開始できない。管理用フローは
        // URLへ直列化されない PasscodeRouteArgs がある場合だけ許可する。
        if (isInternalPasscodeFlow) return null;
        final from = safePasscodeReturnLocation(
          state.uri.queryParameters['from'],
        );
        if (from != null) {
          return from;
        }
        return '/';
      }
      return null;
    },
    routes: $appRoutes,
  );
  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });
  return router;
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// 通常起動の認証判定中・失敗時はルート画面で待機／再試行する。
bool shouldKeepStartupSplashVisible({
  required AsyncValue<bool> securityGuardState,
  required String matchedLocation,
}) {
  return (securityGuardState.isLoading || securityGuardState.hasError) &&
      matchedLocation == '/';
}

@TypedGoRoute<RootRoute>(
  path: '/',
  routes: [
    TypedGoRoute<MediaViewerRoute>(path: 'viewer/:id'),
    TypedGoRoute<TagManagementRoute>(path: 'tags'),
    TypedGoRoute<SettingsRoute>(path: 'settings'),
    TypedGoRoute<PrivacySettingsRoute>(path: 'privacy'),
    TypedGoRoute<InfoRoute>(path: 'info'),
    TypedGoRoute<ArchiveRoute>(path: 'archive'),
    TypedGoRoute<TrashRoute>(path: 'trash'),
  ],
)
class RootRoute extends GoRouteData with $RootRoute {
  const RootRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const InitializationFlowScreen();
  }
}

class MediaViewerRoute extends GoRouteData with $MediaViewerRoute {
  const MediaViewerRoute({required this.id, this.$extra});
  final int id;
  final ViewerRouteArgs? $extra;

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    final child = MediaViewerScreen(
      initialItemId: id,
      initialItem: $extra?.initialItem,
      sourceContext: $extra?.sourceContext,
    );

    // iOS の場合は標準のバックジェスチャーをサポートするために CupertinoPage を使用
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoPage(key: state.pageKey, child: child);
    }

    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
          child: child,
        );
      },
    );
  }
}

class TagManagementRoute extends GoRouteData with $TagManagementRoute {
  const TagManagementRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const TagManagementScreen();
}

class SettingsRoute extends GoRouteData with $SettingsRoute {
  const SettingsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsPage();
}

class PrivacySettingsRoute extends GoRouteData with $PrivacySettingsRoute {
  const PrivacySettingsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const PrivacySettingsPage();
}

class InfoRoute extends GoRouteData with $InfoRoute {
  const InfoRoute({required this.title, required this.content});
  final String title;
  final String content;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      InfoPage(title: title, content: content);
}

class ArchiveRoute extends GoRouteData with $ArchiveRoute {
  const ArchiveRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ArchiveScreen();
}

class TrashRoute extends GoRouteData with $TrashRoute {
  const TrashRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const TrashScreen();
}

@TypedGoRoute<PasscodeRoute>(path: '/passcode')
class PasscodeRoute extends GoRouteData with $PasscodeRoute {
  const PasscodeRoute({this.from, this.$extra});
  final String? from;
  final PasscodeRouteArgs? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final args = $extra;
    final mode = args?.mode ?? PasscodeMode.unlock;
    return PasscodeScreen(
      mode: mode,
      title: args?.title,
      allowBiometrics: args?.allowBiometrics ?? true,
      onSuccess:
          args?.onSuccess ??
          (mode == PasscodeMode.unlock
              ? () {
                  final container = ProviderScope.containerOf(context);
                  container.read(securityGuardProvider.notifier).unlock();
                  final safeFrom = safePasscodeReturnLocation(from);
                  if (safeFrom != null) {
                    GoRouter.of(context).go(safeFrom);
                  } else {
                    GoRouter.of(context).go('/');
                  }
                }
              : null),
    );
  }
}

/// ロック解除後の復帰先として、アプリ内の絶対パスだけを許可する。
String? safePasscodeReturnLocation(String? value) {
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      uri.path.startsWith('//') ||
      uri.path == '/passcode') {
    return null;
  }
  return uri.toString();
}

/// URLから復元できない、アプリ内部専用のパスコード操作引数。
///
/// 外部ディープリンクは `extra` を供給できないため、`/passcode` は常に
/// 解除モードとして扱われる。設定・変更フローはこの引数を伴う内部遷移だけで開始する。
@immutable
class PasscodeRouteArgs {
  const PasscodeRouteArgs({
    required this.mode,
    this.title,
    this.allowBiometrics = true,
    this.onSuccess,
  });

  final PasscodeMode mode;
  final String? title;
  final bool allowBiometrics;
  final VoidCallback? onSuccess;
}
