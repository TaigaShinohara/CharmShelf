import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../features/tip/presentation/providers/tip_purchase_provider.dart';

import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

import 'package:secure_application/secure_application.dart';

import '../features/settings/presentation/providers/privacy_settings_provider.dart';
import '../features/settings/presentation/screens/lock_screen.dart';
import '../features/settings/presentation/widgets/app_lock_manager.dart';

import '../core/config/app_config.dart';
import '../core/config/feature_flags.dart';
import '../core/debug/dip.dart';
import '../core/providers/package_info_provider.dart';
import '../core/router/app_router.dart';
import '../core/system/system_ui_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../core/theme/app_skeletonizer_config.dart';
import '../features/settings/presentation/providers/app_mode_provider.dart';
import '../features/settings/presentation/providers/locale_provider.dart';
import '../shared/widgets/feedback/app_snackbar.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 画面を開かなくても未完了取引を受信する。デスクトップ/Webは対象外。
    if (FeatureFlags.enableSupportPurchases &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      ref.watch(tipPurchaseServiceProvider);
    }
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    final title = ref.watch(appNameProvider);
    final isExternalMode = ref.watch(isExternalModeProvider);

    // DIPオーバーライド設定の解決
    final dip = DipRuntimeOverrides.read(ref);
    final appLocale = ref.watch(appLocaleProvider);
    final locale = appLocale ?? dip.locale;

    final mainApp = MaterialApp.router(
      title: title,
      theme: AppTheme.lightWith(
        primaryColor: dip.customColors?.primaryColor,
        secondaryColor: dip.customColors?.secondaryColor,
        isExternalMode: isExternalMode,
      ),
      darkTheme: AppTheme.darkWith(
        primaryColor: dip.customColors?.primaryColor,
        secondaryColor: dip.customColors?.secondaryColor,
        isExternalMode: isExternalMode,
      ),
      themeMode: themeMode,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppConfig.supportedLocales,
      showPerformanceOverlay: dip.showPerformanceOverlay,
      debugShowCheckedModeBanner: false,
      showSemanticsDebugger: dip.showSemanticsDebugger,
      builder: (context, child) {
        // 全体のコンテキスト（LockScreenなども含む）に適用するラップ
        Widget content = SecureApplication(
          nativeRemoveDelay: 800,
          autoUnlockNative: false, // AppLockManagerで制御するためfalse
          child: PrivacySecurityWrapper(
            child: AppLockManager(
              child: SecureGate(
                blurr: 60,
                opacity: 0.8,
                lockedBuilder: (context, secureNotifier) => const LockScreen(),
                // OSのTextScalerをそのまま保持する。文字拡大を画面全体で
                // 制限せず、各レイアウト側で大きな文字に適応する。
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );

        // DIPパネルのテキストスケールオーバーライド
        if (dip.textScale != 1.0) {
          content = MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(dip.textScale)),
            child: content,
          );
        }

        final theme = Theme.of(context);
        return AppSnackBarOverlayHost(
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUIService.overlayStyleFor(
              theme.brightness,
              navigationBarColor: theme.colorScheme.surface,
            ),
            child: AppSkeletonizerConfig(child: content),
          ),
        );
      },
    );

    return DipAppWrapper(child: mainApp);
  }
}

/// プライバシー設定とSecureApplicationの連携を行うラッパー
class PrivacySecurityWrapper extends ConsumerWidget {
  final Widget child;

  const PrivacySecurityWrapper({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secureController = SecureApplicationProvider.of(context);

    // 画面保護だけを hideContentInMultitasking と同期する。
    // アプリロックは AppLockManager が独立して制御する。
    ref.listen(privacySettingsNotifierProvider, (previous, next) {
      final prevSettings = previous?.value;
      final nextSettings = next.value;

      if (nextSettings != null &&
          secureController != null &&
          prevSettings?.hideContentInMultitasking !=
              nextSettings.hideContentInMultitasking) {
        if (nextSettings.hideContentInMultitasking) {
          if (!secureController.value.secured) {
            secureController.secure();
          }
        } else {
          if (secureController.value.secured) {
            secureController.open();
          }
        }
      }
    });

    return child;
  }
}
