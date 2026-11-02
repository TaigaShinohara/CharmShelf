import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app.dart';
import 'app/initialization_flow.dart';
import 'app/fresh_start_scope.dart';
import 'features/onboarding/data/fresh_start_service.dart';
import 'app/startup_failure_app.dart';
import 'core/config/app_config.dart';
import 'core/config/feature_flags.dart';
import 'core/debug/dip.dart';
import 'core/error/crash_report_service.dart';
import 'core/error/error_handler.dart';
import 'core/logger/app_logger.dart';
import 'core/logger/log_tag.dart';
import 'core/performance/image_cache_policy.dart';
import 'core/providers/path_provider.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/license_service.dart';
import 'core/services/app_review_service.dart';
import 'core/services/private_storage_service.dart';
import 'core/system/system_ui_service.dart';
import 'core/theme/app_theme.dart';
import 'core/watch/watch_os_service.dart';
import 'features/splash/presentation/screens/app_splash_screen.dart';
import 'features/security/data/repositories/security_repository_impl.dart';
import 'features/security/presentation/providers/security_repository_provider.dart';
import 'features/security/presentation/providers/security_guard_provider.dart';
import 'features/settings/data/repositories/privacy_repository.dart';
import 'features/settings/presentation/providers/privacy_settings_provider.dart';
import 'gen_l10n/app_localizations.dart';

Future<void> _runBestEffortInit(
  String label,
  Future<void> Function() task,
) async {
  try {
    await task();
  } catch (error, stackTrace) {
    AppLogger.w(LogTag.lifecycle, '初期化に失敗: $label', error, stackTrace);
  }
}

Future<void> _runAfterFirstFrameInit(SharedPreferences prefs) async {
  await Future.wait([
    _runBestEffortInit('audio_background', () async {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.tsmusic.privateshelf.channel.audio',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationIcon: 'drawable/ic_notification',
        androidNotificationOngoing: false,
      );
    }),
    _runBestEffortInit(
      'responsive_orientation',
      () => SystemUIService.setResponsiveOrientations(),
    ),
    if (FeatureFlags.enableWatchOs)
      _runBestEffortInit(
        'watch_os',
        () => WatchOsService.instance.initialize(),
      ),
    _runBestEffortInit(
      'crash_report',
      () => CrashReportService.instance.initialize(),
    ),
    _runBestEffortInit(
      'local_notification',
      () => LocalNotificationService().init(),
    ),
    if (FeatureFlags.enableAppReview)
      _runBestEffortInit(
        'app_review_launch',
        () => AppReviewService().recordAppLaunch(prefs),
      ),
  ]);
  AppLogger.d(LogTag.app, '初回フレーム後の補助サービス初期化を完了');
}

Future<({SharedPreferences prefs, Directory privateStorageDir})>
_loadCriticalDependencies() async {
  final results = await Future.wait<Object>([
    SharedPreferences.getInstance(),
    PrivateStorageService.prepare(),
  ], eagerError: false);
  // A confirmed reset must finish before old PIN/settings or legacy recovery
  // can expose partially cleared data. No marker means no storage work.
  final recoveryContainer = ProviderContainer(retry: (_, _) => null);
  try {
    await recoveryContainer.read(freshStartServiceProvider).recoverPending();
  } finally {
    recoveryContainer.dispose();
  }
  return (
    prefs: results[0] as SharedPreferences,
    privateStorageDir: results[1] as Directory,
  );
}

Widget _buildMainApp(
  SharedPreferences prefs,
  Directory privateStorageDir,
  VoidCallback onStartupReady,
) {
  return FreshStartScope(
    overrides: [
      privacyRepositoryProvider.overrideWith((ref) => PrivacyRepository(prefs)),
      securityRepositoryProvider.overrideWith(
        (ref) => ref.watch(securityRepositoryImplProvider),
      ),
      appDocumentsPathSyncProvider.overrideWith(
        (ref) => privateStorageDir.path,
      ),
    ],
    child: _StartupReadyObserver(onReady: onStartupReady, child: const MyApp()),
  );
}

class _StartupReadyObserver extends ConsumerWidget {
  const _StartupReadyObserver({required this.onReady, required this.child});

  final VoidCallback onReady;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guard = ref.watch(securityGuardProvider);
    final flow = guard.value == true
        ? ref.watch(initializationFlowAsyncProvider)
        : null;
    if (guard.hasError ||
        guard.value == false ||
        (flow != null &&
            (flow.hasError ||
                (flow.hasValue && flow.value != InitFlowState.launch)))) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onReady());
    }
    return child;
  }
}

class _StartupBootstrap extends StatefulWidget {
  const _StartupBootstrap();

  @override
  State<_StartupBootstrap> createState() => _StartupBootstrapState();
}

class _StartupBootstrapState extends State<_StartupBootstrap> {
  ({SharedPreferences prefs, Directory privateStorageDir})? _dependencies;
  Future<({SharedPreferences prefs, Directory privateStorageDir})>?
  _criticalLoad;
  Object? _error;
  int _attempt = 0;
  bool _showSplash = true;

  void _finishSplash() {
    if (mounted && _showSplash) setState(() => _showSplash = false);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<bool> _load() async {
    final attempt = ++_attempt;
    if (mounted) {
      setState(() {
        _error = null;
        _showSplash = true;
      });
    }
    final load = _criticalLoad ??= _loadCriticalDependencies();
    try {
      final dependencies = await load.timeout(const Duration(seconds: 12));
      if (!mounted || attempt != _attempt) return false;
      setState(() => _dependencies = dependencies);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_runAfterFirstFrameInit(dependencies.prefs));
      });
      return true;
    } catch (error, stackTrace) {
      // タイムアウトは処理自体を中断しない。同じFutureを再利用し、
      // 私有領域の準備を重複実行しない。明示的な失敗時だけ再試行を許可する。
      if (error is! TimeoutException && identical(_criticalLoad, load)) {
        _criticalLoad = null;
      }
      GlobalErrorHandler.log(
        error,
        stackTrace,
        context: 'Critical startup initialization failed',
      );
      if (mounted && attempt == _attempt) setState(() => _error = error);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = _dependencies;
    if (_error != null) {
      return StartupFailureApp(onRetry: _load);
    }
    return Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.expand,
      children: [
        if (dependencies != null)
          ExcludeSemantics(
            excluding: _showSplash,
            child: IgnorePointer(
              ignoring: _showSplash,
              child: _buildMainApp(
                dependencies.prefs,
                dependencies.privateStorageDir,
                _finishSplash,
              ),
            ),
          )
        else
          const SizedBox.expand(),
        if (_showSplash) _buildSplashApp(preparingData: dependencies != null),
      ],
    );
  }

  Widget _buildSplashApp({required bool preparingData}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppConfig.supportedLocales,
    home: Builder(
      builder: (context) => AppSplashScreen(
        statusText: preparingData
            ? AppLocalizations.of(context)?.startupPreparingData
            : AppLocalizations.of(context)?.startupPreparingStorage,
      ),
    ),
  );
}

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    // ── 画像キャッシュの最適化 ──
    // 通常時はメモリを抑え、ビューワー表示中だけ専用リースで一時的に拡張する。
    AppImageCachePolicy.apply(PaintingBinding.instance.imageCache);

    // ── システム初期化（runApp前に高速で完了させる） ──
    AppLogger.separator('アプリ起動');
    AppLogger.i(LogTag.lifecycle, 'アプリを起動しています...');
    GlobalErrorHandler.install();
    AppLogger.d(LogTag.app, 'グローバルエラーハンドラーをインストール');

    SystemUIService.setImmersiveStatusBar();

    // ライセンス登録はメモリ上の同期処理なので、Future として待機しない。
    LicenseService.registerCustomLicenses();

    if (FeatureFlags.enableDip) {
      initializeDip();
      AppLogger.d(LogTag.app, 'DIP（開発者パネル）を初期化');
    }

    // 先にFlutterのスプラッシュを描画し、必須依存はその裏で準備する。
    runApp(const _StartupBootstrap());
  }, (error, stack) => GlobalErrorHandler.handleZoneError(error, stack));
}
