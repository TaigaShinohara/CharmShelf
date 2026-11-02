import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'package:private_shelf/core/logger/app_logger.dart';
import 'package:private_shelf/core/logger/log_tag.dart';
import 'import_picker_session.dart';

final _pickerSession = ImportPickerSession();

Future<T?> runImportPicker<T>({
  required Future<T?> Function() pick,
  String? title,
  String? body,
}) => _pickerSession.run(
  pick: pick,
  showNotification: () => showPickerNotification(title: title, body: body),
  hideNotification: cancelPickerNotification,
  returns: onReturnFromNotification,
);

/// ファイルピッカーが開いている間に使用する MethodChannel
const _safChannel = MethodChannel('com.tsmusic.privateshelf/saf');

/// ファイルピッカー表示中にネイティブ通知を出し、タップでアプリに復帰できるようにするヘルパー。
///
/// Android の NotificationManager を直接使用するため、
/// Flutter の LocalNotificationService の初期化状態に依存しない。

final _returnStreamController = StreamController<void>.broadcast();

/// 通知経由でアプリに復帰したイベントのストリーム
Stream<void> get onReturnFromNotification => _returnStreamController.stream;

/// ネイティブ側からの呼び出しをリッスンする
void initializeImportPickerListener() {
  if (!Platform.isAndroid) return;
  _safChannel.setMethodCallHandler((call) async {
    if (call.method == 'onReturnFromNotification') {
      AppLogger.d(LogTag.notification, '通知からの復帰イベントを受信');
      // shared_storage プラグイン内部の保留中リクエストを強制キャンセル
      try {
        const sharedStorageChannel = MethodChannel(
          'io.alexrintt.plugins/sharedstorage/documentfile',
        );
        await sharedStorageChannel.invokeMethod('cancelAllRequests');
        AppLogger.d(LogTag.notification, 'shared_storage の保留中リクエストを解除');
      } catch (e) {
        AppLogger.w(LogTag.notification, 'shared_storage のリセットに失敗: $e');
      }
      try {
        await const MethodChannel(
          'miguelruivo.flutter.plugins.filepicker',
        ).invokeMethod<void>('cancelPendingRequest');
      } catch (e) {
        AppLogger.w(LogTag.notification, 'file_picker のリセットに失敗: $e');
      }
      _returnStreamController.add(null);
    }
  });
}

/// 通知経由でアプリに復帰するのを待機する
Future<void> waitForReturn() async {
  await onReturnFromNotification.first;
}

Future<void> showPickerNotification({String? title, String? body}) async {
  if (!Platform.isAndroid) return;
  try {
    final status = await ph.Permission.notification.status;
    if (!status.isGranted) {
      // インポート通知は補助機能であり、ファイル選択の必須条件ではない。
      // 権限を自動要求せず、未許可の場合は通知なしで処理を継続する。
      AppLogger.i(LogTag.notification, '通知権限が未許可のため、ピッカー復帰通知を表示せず続行');
      return;
    }
  } catch (error, stack) {
    AppLogger.w(LogTag.notification, '通知権限の確認に失敗したため、通知なしで続行', error, stack);
    return;
  }
  initializeImportPickerListener();
  try {
    final useEnglish = PlatformDispatcher.instance.locale.languageCode == 'en';
    await _safChannel.invokeMethod('showPickerNotification', {
      'title': title ?? (useEnglish ? 'Return to CharmShelf' : 'CharmShelf に戻る'),
      'body':
          body ??
          (useEnglish
              ? 'Tap to cancel the picker and return to the app'
              : 'タップするとファイル選択を中断してアプリに戻ります'),
    });
    AppLogger.d(LogTag.notification, 'ピッカー通知を表示');
  } catch (e, st) {
    // 通知失敗はインポート処理自体を妨げない
    AppLogger.e(LogTag.notification, 'ピッカー通知表示に失敗', e, st);
  }
}

/// ファイルピッカーから戻った後に通知を消去する。
Future<void> cancelPickerNotification() async {
  if (!Platform.isAndroid) return;
  try {
    await _safChannel.invokeMethod('cancelPickerNotification');
    AppLogger.d(LogTag.notification, 'ピッカー通知を消去');
  } catch (e, st) {
    AppLogger.e(LogTag.notification, 'ピッカー通知消去に失敗', e, st);
  }
}
