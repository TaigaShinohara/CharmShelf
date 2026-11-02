import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/feature_flags.dart';
import '../logger/app_logger.dart';
import '../logger/log_tag.dart';
import '../providers/shared_preferences_provider.dart';

/// 受信したディープリンク遷移先（保留含む）
///
/// - 初期化フロー未完了の場合は、この値を保持しておき、ready後に遷移します
final pendingDeepLinkLocationProvider = StateProvider<String?>((ref) => null);

final deepLinkHandlerProvider = Provider<DeepLinkHandler>((ref) {
  final handler = DeepLinkHandler();
  ref.onDispose(handler.dispose);
  return handler;
});

enum DeepLinkTabTarget { library, home, preserve }

class DeepLinkHandler {
  static const _pendingKey = 'pending_deep_link_location';

  bool _started = false;
  StreamSubscription<Uri>? _sub;

  /// 初回リンク + 起動中/復帰時リンクを購読して、遷移先を保存します。
  ///
  /// 注意: このメソッドは複数回呼ばれても問題ないようガードしています。
  void ensureStarted(WidgetRef ref) {
    if (_started) return;
    _started = true;

    () async {
      if (!FeatureFlags.enableDeepLink) return;

      final prefs = await ref.read(sharedPreferencesProvider.future);

      // 起動時に既に保留があれば復元
      final existing = prefs.getString(_pendingKey);
      if (existing != null && existing.isNotEmpty) {
        ref.read(pendingDeepLinkLocationProvider.notifier).state = existing;
      }

      final appLinks = AppLinks();

      // Cold start 用（最初のリンク）
      try {
        final initial = await appLinks.getInitialLink();
        if (initial != null) {
          await _handleUri(ref, prefs, initial);
        }
      } catch (e, st) {
        AppLogger.e(LogTag.app, 'ディープリンク: 初期リンク取得に失敗', e, st);
      }

      // 起動中/復帰時（以後すべて）
      _sub = appLinks.uriLinkStream.listen(
        (uri) async {
          await _handleUri(ref, prefs, uri);
        },
        onError: (e, st) {
          final stack = st is StackTrace ? st : null;
          AppLogger.e(LogTag.app, 'ディープリンク: ストリームエラー', e, stack);
        },
      );
    }();
  }

  Future<void> clearPending(WidgetRef ref) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.remove(_pendingKey);
    ref.read(pendingDeepLinkLocationProvider.notifier).state = null;
  }

  Future<void> _handleUri(
    WidgetRef ref,
    SharedPreferences prefs,
    Uri uri,
  ) async {
    final location = toLocation(uri);
    if (location == null) return;

    await prefs.setString(_pendingKey, location);
    ref.read(pendingDeepLinkLocationProvider.notifier).state = location;

    AppLogger.i(LogTag.navigation, 'ディープリンク受信: $uri -> $location');
  }

  /// アプリが実際に扱えるディープリンクだけを正規化する。
  ///
  /// 任意のパスやクエリをルーターへ渡さず、extraが必要なviewer等も対象外とする。
  static String? toLocation(Uri uri) {
    final scheme = FeatureFlags.deepLinkScheme;
    if (uri.scheme != scheme) return null;
    if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) return null;

    // 例: myapp://settings  (host=settings, path="")
    // 例: myapp://home/detail?id=123  (host=home, path=/detail)
    final key = uri.host.isNotEmpty
        ? uri.host
        : (uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '');

    if (key.isEmpty) return '/';
    final consumedHost = uri.host.isNotEmpty;
    final remainingSegments = consumedHost
        ? uri.pathSegments
        : uri.pathSegments.skip(1);
    if (remainingSegments.isNotEmpty) return null;

    return switch (key) {
      'library' => '/',
      'home' => '/home',
      'settings' => '/settings',
      'privacy' => '/privacy',
      'info' => '/info',
      'archive' => '/archive',
      'trash' => '/trash',
      'tags' => '/tags',
      _ => null,
    };
  }

  static DeepLinkTabTarget tabTargetFor(String location) {
    return switch (location) {
      '/' => DeepLinkTabTarget.library,
      '/home' => DeepLinkTabTarget.home,
      _ => DeepLinkTabTarget.preserve,
    };
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
