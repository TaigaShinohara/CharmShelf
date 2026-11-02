import '../error/app_error.dart';
import '../error/result.dart';

typedef NotificationPayload = String?;
typedef OnNotificationTap = void Function(NotificationPayload payload);

/// ローカル通知を管理するサービス（Web用スタブ）
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService _instance =
      LocalNotificationService._();
  static LocalNotificationService get instance => _instance;

  factory LocalNotificationService() => _instance;

  bool get isInitialized => true;

  NotificationPayload? get launchPayload => null;

  Future<Result<void, AppError>> init({OnNotificationTap? onTap}) async {
    return Result.success(null);
  }

  Future<Result<bool, AppError>> requestPermission() async {
    return Result.success(false);
  }

  Future<Result<void, AppError>> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
    String? channelName,
  }) async {
    return Result.failure(AppError.validation('Webではローカル通知は利用できません'));
  }

  Future<Result<void, AppError>> showProgress({
    required int id,
    required String title,
    required String body,
    required int maxProgress,
    required int currentProgress,
    bool indeterminate = false,
    String? payload,
    String? channelId,
    String? channelName,
    bool ongoing = true,
    Duration throttleDuration = const Duration(milliseconds: 500),
    bool forceUpdate = false,
  }) async {
    return Result.failure(AppError.validation('Webではローカル通知は利用できません'));
  }

  Future<Result<void, AppError>> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    String? channelId,
    String? channelName,
  }) async {
    return Result.failure(AppError.validation('Webではローカル通知は利用できません'));
  }

  Future<void> cancel(int id) async {}
}
