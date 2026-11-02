import 'dart:io';

import 'package:flutter/services.dart';

class PrivacyNativeService {
  const PrivacyNativeService();

  static const MethodChannel _channel = MethodChannel(
    'com.tsmusic.privateshelf/privacy',
  );

  Future<bool> applyMultitaskSecure(bool enabled) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }
    try {
      await _channel.invokeMethod('setMultitaskSecure', {'enabled': enabled});
      return true;
    } on PlatformException {
      return false;
    }
  }
}
