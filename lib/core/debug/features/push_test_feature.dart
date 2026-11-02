import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feedback/snackbar_service.dart';
import '../dip_action_log.dart';
import '../dip_feature.dart';

/// プッシュ通知テスト機能
class PushTestFeature extends PanelDipFeature {
  @override
  String get id => 'push_test';

  @override
  String get title => 'プッシュ通知テスト';

  @override
  String? get subtitle => 'ローカル通知を送信';

  @override
  IconData get icon => Icons.notifications_active;

  @override
  DipFeatureCategory get category => DipFeatureCategory.test;

  @override
  Widget? buildPanel(BuildContext context) {
    return const _PushTestPanel();
  }
}

class _PushTestPanel extends ConsumerStatefulWidget {
  const _PushTestPanel();

  @override
  ConsumerState<_PushTestPanel> createState() => _PushTestPanelState();
}

class _PushTestPanelState extends ConsumerState<_PushTestPanel> {
  final _titleController = TextEditingController(text: 'テスト通知');
  final _bodyController = TextEditingController(text: 'これはDIPからのテスト通知です');
  int _delaySeconds = 0;
  bool _sending = false;

  late FlutterLocalNotificationsPlugin _notifications;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    _notifications = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings: initSettings);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 通知内容入力
        Text(
          '通知内容',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'タイトル',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bodyController,
                  decoration: const InputDecoration(
                    labelText: '本文',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 遅延設定
        Text(
          '送信タイミング',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_delaySeconds == 0 ? '即時送信' : '$_delaySeconds秒後に送信'),
                Slider(
                  value: _delaySeconds.toDouble(),
                  min: 0,
                  max: 60,
                  divisions: 12,
                  label: _delaySeconds == 0 ? '即時' : '$_delaySeconds秒',
                  onChanged: (value) =>
                      setState(() => _delaySeconds = value.round()),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 送信ボタン
        ElevatedButton.icon(
          onPressed: _sending ? null : () => _sendNotification(context),
          icon: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: const Text('通知を送信'),
        ),
        const SizedBox(height: 24),
        // プリセット
        Text(
          'プリセット',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PresetChip(
              label: '新着メッセージ',
              onTap: () {
                _titleController.text = '新着メッセージ';
                _bodyController.text = '田中さんからメッセージが届きました';
                setState(() {});
              },
            ),
            _PresetChip(
              label: 'リマインダー',
              onTap: () {
                _titleController.text = 'リマインダー';
                _bodyController.text = '予定の時間です';
                setState(() {});
              },
            ),
            _PresetChip(
              label: 'アップデート',
              onTap: () {
                _titleController.text = 'アプリのアップデート';
                _bodyController.text = '新しいバージョンが利用可能です';
                setState(() {});
              },
            ),
            _PresetChip(
              label: 'プロモーション',
              onTap: () {
                _titleController.text = '期間限定キャンペーン';
                _bodyController.text = '今だけ30%OFF！お見逃しなく';
                setState(() {});
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        // 注意事項
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '注意事項',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• これはローカル通知です（サーバーからの通知ではありません）\n'
                  '• 通知の許可が必要です\n'
                  '• 遅延送信中にアプリを閉じても通知は届きます',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendNotification(BuildContext context) async {
    setState(() => _sending = true);

    try {
      const androidDetails = AndroidNotificationDetails(
        'dip_test',
        'DIPテスト通知',
        channelDescription: 'DIPからのテスト通知',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final id = Random().nextInt(100000);

      if (_delaySeconds > 0) {
        // 遅延後に即時通知を送信
        await Future.delayed(Duration(seconds: _delaySeconds));
        await _notifications.show(
          id: id,
          title: _titleController.text,
          body: _bodyController.text,
          notificationDetails: details,
        );
        DipActionLog.success('通知をスケジュール: $_delaySeconds秒後', tag: 'Push');
      } else {
        // 即時通知
        await _notifications.show(
          id: id,
          title: _titleController.text,
          body: _bodyController.text,
          notificationDetails: details,
        );
        DipActionLog.success('通知を送信しました', tag: 'Push');
      }

      if (context.mounted) {
        ref
            .read(snackBarServiceProvider)
            .success(
              context: context,
              message: _delaySeconds > 0
                  ? '$_delaySeconds秒後に通知が届きます'
                  : '通知を送信しました',
            );
      }
    } catch (e) {
      DipActionLog.error('通知送信失敗: $e', tag: 'Push');
      if (context.mounted) {
        ref
            .read(snackBarServiceProvider)
            .error(context: context, message: 'エラー: $e');
      }
    } finally {
      setState(() => _sending = false);
    }
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}
