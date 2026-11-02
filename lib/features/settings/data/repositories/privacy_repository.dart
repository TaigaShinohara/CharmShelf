import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/error/app_error.dart'; // Verify path
import '../../../../core/error/result.dart'; // Corrected path
import '../../domain/models/privacy_settings.dart';

class PrivacyRepository {
  final SharedPreferences _prefs;
  static const _key = 'privacy_settings';

  PrivacyRepository(this._prefs);

  Future<Result<PrivacySettings, AppError>> loadSettings() async {
    try {
      final jsonString = _prefs.getString(_key);
      if (jsonString == null) {
        return Result.success(const PrivacySettings());
      }
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final settings = PrivacySettings.fromJson(jsonMap);
      return Result.success(settings);
    } catch (e, st) {
      return Result.failure(
        AppError.unknown('プライバシー設定の読み込みに失敗しました', original: e, stackTrace: st),
      );
    }
  }

  Future<Result<void, AppError>> saveSettings(PrivacySettings settings) async {
    try {
      final jsonString = jsonEncode(settings.toJson());
      final saved = await _prefs.setString(_key, jsonString);
      if (!saved) {
        return Result.failure(AppError.unknown('プライバシー設定を保存できませんでした'));
      }
      return Result.success(null);
    } catch (e) {
      return Result.failure(AppError.unknown(e.toString()));
    }
  }
}
