import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_notification_service.dart';

/// LocalNotificationService のシングルトンProvider
///
/// 使用前に必ず `init()` を呼び出してください。
/// 通常は `InitializationFlowScreen` や `main.dart` で初期化します。
///
/// ```dart
/// // 初期化（アプリ起動時に一度だけ）
/// final service = ref.read(localNotificationServiceProvider);
/// await service.init(onTap: (payload) {
///   if (payload != null && context.mounted) {
///     GoRouter.of(context).go(payload);
///   }
/// });
///
/// // 通知を表示
/// await service.showNow(
///   id: 1,
///   title: '新着メッセージ',
///   body: 'メッセージが届きました',
///   payload: '/messages/123',
/// );
/// ```
final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  return LocalNotificationService();
});

/// 通知サービスが初期化済みかどうか
final isNotificationInitializedProvider = Provider<bool>((ref) {
  final service = ref.watch(localNotificationServiceProvider);
  return service.isInitialized;
});

/// 起動時に通知タップで開かれた場合のペイロード
///
/// アプリが通知タップで起動された場合、ここに遷移先のパスが入ります。
/// 初期化フロー完了後にこの値をチェックして遷移を行います。
///
/// ```dart
/// // InitializationFlowScreen などで使用
/// ref.listen(launchNotificationPayloadProvider, (prev, next) {
///   if (next != null && state == InitFlowState.ready) {
///     context.go(next);
///   }
/// });
/// ```
final launchNotificationPayloadProvider = Provider<String?>((ref) {
  final service = ref.watch(localNotificationServiceProvider);
  return service.launchPayload;
});
