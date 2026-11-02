import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../error/app_error.dart';
import '../error/result.dart';
import '../logger/app_logger.dart';
import '../logger/log_tag.dart';

part 'local_notification_service_io.g.dart';

/// 通知タップ時のペイロード（go_routerのパス文字列を想定）
typedef NotificationPayload = String?;

/// 通知タップ時のコールバック
typedef OnNotificationTap = void Function(NotificationPayload payload);

/// ローカル通知を管理するサービス（iOS/Android/desktop用）
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService _instance =
      LocalNotificationService._();
  static LocalNotificationService get instance => _instance;

  factory LocalNotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  Future<Result<void, AppError>>? _initFuture;

  bool _isTimezoneInitialized = false;
  Future<void>? _timezoneInitFuture;

  OnNotificationTap? _onTap;

  /// 起動時に通知タップで開かれた場合のペイロード
  NotificationPayload? _launchPayload;
  NotificationPayload? get launchPayload => _launchPayload;

  /// 各通知IDごとの最終進捗通知送信時刻（スロットリング用）
  final Map<int, DateTime> _lastProgressUpdatedTimes = {};

  /// 初期化
  ///
  /// [onTap] 通知タップ時のコールバック（payloadにgo_routerのパスが入る）
  Future<Result<void, AppError>> init({OnNotificationTap? onTap}) {
    if (onTap != null) {
      _onTap = onTap;
    }

    if (_isInitialized) {
      return Future.value(Result.success(null));
    }

    // 遅延初期化と明示初期化が重なっても、プラグイン初期化は一度だけ実行する。
    return _initFuture ??= _initialize();
  }

  Future<Result<void, AppError>> _initialize() async {
    try {
      // Android設定
      const androidSettings = AndroidInitializationSettings('ic_notification');

      // iOS設定
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      // アプリ起動時に通知から開かれたかチェック
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        _launchPayload = launchDetails?.notificationResponse?.payload;
        AppLogger.i(LogTag.notification, '通知からアプリを起動, ペイロード: $_launchPayload');
      }

      _isInitialized = true;
      AppLogger.i(LogTag.notification, '通知サービスを初期化完了');
      return Result.success(null);
    } catch (e, st) {
      // 一時的なプラットフォームエラーの場合は次回利用時に再試行できるようにする。
      _initFuture = null;
      AppLogger.e(LogTag.notification, '通知サービスの初期化に失敗', e, st);
      return Result.failure(
        AppError.unknown('通知の初期化に失敗しました', original: e, stackTrace: st),
      );
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    AppLogger.d(
      LogTag.notification,
      '通知がタップされました: id=${response.id}, ペイロード=${response.payload}',
    );
    _onTap?.call(response.payload);
  }

  /// 通知許可をリクエスト
  ///
  /// iOSでは明示的な許可が必要です。
  /// Androidでは Android 13+ で必要です。
  Future<Result<bool, AppError>> requestPermission() async {
    try {
      bool? granted;

      if (Platform.isIOS || Platform.isMacOS) {
        granted = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } else if (Platform.isAndroid) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        // Android 13+ の通知許可
        granted = await androidPlugin?.requestNotificationsPermission();
      }

      final result = granted ?? true;
      AppLogger.i(LogTag.notification, '通知許可: ${result ? "許可" : "拒否"}');
      return Result.success(result);
    } catch (e, st) {
      AppLogger.e(LogTag.notification, '通知許可のリクエストに失敗', e, st);
      return Result.failure(
        AppError.unknown('通知許可のリクエストに失敗しました', original: e, stackTrace: st),
      );
    }
  }

  /// 進捗通知を表示
  ///
  /// [throttleDuration] 同一IDに対する通知更新の最小間隔（デフォルト: 500ms）。
  /// Android OSのレートリミット（秒間5回）超過やUIブロックを防ぐために間引きを行います。
  /// [forceUpdate] true の場合、スロットリング間隔を無視して即座に通知を更新します。
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
    await _ensureInitialized();

    // 進捗完了時（100%達成時）や強制更新時はスロットリングをバイパスする
    final isCompleted =
        !indeterminate && maxProgress > 0 && currentProgress >= maxProgress;
    final shouldBypassThrottle = forceUpdate || isCompleted;

    if (!shouldBypassThrottle && throttleDuration > Duration.zero) {
      final now = DateTime.now();
      final lastUpdated = _lastProgressUpdatedTimes[id];
      if (lastUpdated != null &&
          now.difference(lastUpdated) < throttleDuration) {
        // レートリミット対策のため更新をスキップ
        return Result.success(null);
      }
      _lastProgressUpdatedTimes[id] = now;
    } else {
      _lastProgressUpdatedTimes[id] = DateTime.now();
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        channelId ?? 'progress_channel',
        channelName ?? '進捗通知',
        importance: Importance.low, // 音を鳴らさない
        priority: Priority.low,
        showProgress: true,
        maxProgress: maxProgress,
        progress: currentProgress,
        indeterminate: indeterminate,
        ongoing: ongoing,
        onlyAlertOnce: true,
      );

      const darwinDetails = DarwinNotificationDetails();

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
      return Result.success(null);
    } catch (e, st) {
      AppLogger.e(LogTag.notification, '進捗通知の表示に失敗', e, st);
      return Result.failure(
        AppError.unknown('進捗通知の表示に失敗しました', original: e, stackTrace: st),
      );
    }
  }

  /// 即時通知を表示
  Future<Result<void, AppError>> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
    String? channelName,
  }) async {
    _lastProgressUpdatedTimes.remove(id);
    await _ensureInitialized();

    try {
      final androidDetails = AndroidNotificationDetails(
        channelId ?? 'default_channel',
        channelName ?? 'デフォルト',
        importance: Importance.high,
        priority: Priority.high,
      );

      const darwinDetails = DarwinNotificationDetails();

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
      AppLogger.d(LogTag.notification, '通知を表示: id=$id');
      return Result.success(null);
    } catch (e, st) {
      AppLogger.e(LogTag.notification, '通知の表示に失敗', e, st);
      return Result.failure(
        AppError.unknown('通知の表示に失敗しました', original: e, stackTrace: st),
      );
    }
  }

  /// 指定時刻に通知をスケジュール
  Future<Result<void, AppError>> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    String? channelId,
    String? channelName,
  }) async {
    try {
      await _ensureInitialized();
      await _ensureTimezoneInitialized();

      final androidDetails = AndroidNotificationDetails(
        channelId ?? 'scheduled_channel',
        channelName ?? 'スケジュール通知',
        importance: Importance.high,
        priority: Priority.high,
      );

      const darwinDetails = DarwinNotificationDetails();

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );

      AppLogger.d(LogTag.notification, '通知をスケジュール: id=$id, 時刻=$tzTime');
      return Result.success(null);
    } catch (e, st) {
      AppLogger.e(LogTag.notification, '通知のスケジュールに失敗', e, st);
      return Result.failure(
        AppError.unknown('通知のスケジュールに失敗しました', original: e, stackTrace: st),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// 指定IDの通知をキャンセルする
  Future<void> cancel(int id) async {
    _lastProgressUpdatedTimes.remove(id);
    try {
      await _plugin.cancel(id: id);
      AppLogger.d(LogTag.notification, '通知をキャンセル: id=$id');
    } catch (e, st) {
      AppLogger.e(LogTag.notification, '通知のキャンセルに失敗', e, st);
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      if (kDebugMode) {
        AppLogger.w(LogTag.notification, '通知サービスが未初期化です。自動でinit()を呼び出します。');
      }
      await init();
    }
  }

  Future<void> _ensureTimezoneInitialized() {
    if (_isTimezoneInitialized) return Future.value();
    return _timezoneInitFuture ??= _initializeTimezone();
  }

  Future<void> _initializeTimezone() async {
    try {
      // 予約通知を使う時だけタイムゾーンDBを展開する。即時通知や通常起動には不要。
      // latest_all ではなく現行IANAゾーンに絞り、初期化コストとバイナリサイズを抑える。
      tz_data.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final timezoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timezoneName));
      _isTimezoneInitialized = true;
      AppLogger.d(LogTag.notification, 'タイムゾーン設定: $timezoneName');
    } catch (_) {
      _timezoneInitFuture = null;
      rethrow;
    }
  }
}

@riverpod
LocalNotificationService localNotificationService(
  Ref ref,
) {
  return LocalNotificationService();
}
