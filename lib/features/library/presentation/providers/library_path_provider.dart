import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'library_path_provider.g.dart';

@riverpod
class LibraryPath extends _$LibraryPath {
  static const _key = 'library_path';

  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> setPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
    state = AsyncData(path);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = const AsyncData(null);
  }
}
