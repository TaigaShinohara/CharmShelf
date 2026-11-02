import 'dart:ui';

import 'package:flutter/material.dart';

/// 私有ストレージの安全確認など、必須の起動処理に失敗した際のフェイルクローズUI。
class StartupFailureApp extends StatefulWidget {
  const StartupFailureApp({required this.onRetry, super.key});

  final Future<bool> Function() onRetry;

  @override
  State<StartupFailureApp> createState() => _StartupFailureAppState();
}

class _StartupFailureAppState extends State<StartupFailureApp> {
  bool _retrying = false;
  bool _retryFailed = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retryFailed = false;
    });
    final recovered = await widget.onRetry();
    if (!mounted || recovered) return;
    setState(() {
      _retrying = false;
      _retryFailed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isJapanese = PlatformDispatcher.instance.locale.languageCode == 'ja';
    final title = isJapanese ? '安全に起動できませんでした' : 'Unable to start safely';
    final description = isJapanese
        ? '保存領域の安全確認を完了できなかったため、データを開いていません。空き容量や端末の状態を確認し、再試行してください。'
        : 'Your data was not opened because the private storage safety check could not be completed. Check the device and available storage, then retry.';
    final retryLabel = isJapanese ? '再試行' : 'Retry';
    final failedLabel = isJapanese
        ? '再試行できませんでした。端末を再起動しても改善しない場合は、サポートに連絡してください。'
        : 'Retry failed. Restart the device and contact support if the issue continues.';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined, size: 64),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(description, textAlign: TextAlign.center),
                    if (_retryFailed) ...[
                      const SizedBox(height: 16),
                      Text(
                        failedLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _retrying ? null : _retry,
                      icon: _retrying
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(retryLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
