import 'package:flutter/services.dart';
import '../logger/app_logger.dart';
import '../logger/log_tag.dart';

/// Apple Watch (watchOS) とのブリッジ通信を管理するサービス
class WatchOsService {
  WatchOsService._();
  static final instance = WatchOsService._();

  static const _channel = MethodChannel('com.tsmusic.template/watch_bridge');

  /// watchOS 側との通信を初期化
  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
    AppLogger.d(LogTag.app, 'Apple Watch ブリッジを初期化しました');
  }

  /// watchOS 側にデータを送信
  Future<void> sendData(Map<String, dynamic> data) async {
    try {
      await _channel.invokeMethod('sendToWatch', data);
      AppLogger.d(LogTag.app, 'Apple Watch にデータを送信しました: $data');
    } on PlatformException catch (e) {
      AppLogger.e(LogTag.app, 'Apple Watch へのデータ送信に失敗しました', e);
    }
  }

  /// watchOS からの受信を処理
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'receivedFromWatch':
        final data = call.arguments as Map<dynamic, dynamic>;
        AppLogger.i(LogTag.app, 'Apple Watch からデータを受信しました: $data');
        // TODO: 受信データの処理ロジックを追加
        break;
      default:
        AppLogger.w(LogTag.app, '未定義のメソッドが呼ばれました: ${call.method}');
    }
  }
}
