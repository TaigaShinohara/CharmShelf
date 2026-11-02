import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 起動に必要な処理が終わるまで表示する静止画面。
class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({
    this.statusText,
    this.statusDelay = Duration.zero,
    super.key,
  });

  static const backgroundColor = Color(0xFFFAFCFC);
  static const _logoAsset = 'assets/images/splash/icon_move_poster.png';

  final String? statusText;
  final Duration statusDelay;

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen> {
  Timer? _statusTimer;
  bool _showStatus = false;

  @override
  void initState() {
    super.initState();
    _scheduleStatus();
  }

  @override
  void didUpdateWidget(covariant AppSplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statusText != widget.statusText ||
        oldWidget.statusDelay != widget.statusDelay) {
      _scheduleStatus();
    }
  }

  void _scheduleStatus() {
    _statusTimer?.cancel();
    _showStatus = false;
    if (widget.statusText == null) return;
    if (widget.statusDelay == Duration.zero) {
      _showStatus = true;
      return;
    }
    _statusTimer = Timer(widget.statusDelay, () {
      if (mounted) setState(() => _showStatus = true);
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusText = widget.statusText;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppSplashScreen.backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: AppSplashScreen.backgroundColor,
        body: SafeArea(
          child: Center(
            child: Semantics(
              container: true,
              liveRegion: _showStatus,
              excludeSemantics: _showStatus,
              label: _showStatus ? statusText : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: 128,
                      child: Image.asset(
                        AppSplashScreen._logoAsset,
                        key: const ValueKey('startup_logo'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    child: _showStatus && statusText != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Text(
                              statusText,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF475569)),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
