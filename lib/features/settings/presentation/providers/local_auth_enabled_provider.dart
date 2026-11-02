import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'privacy_settings_provider.dart';

part 'local_auth_enabled_provider.g.dart';

@riverpod
bool localAuthEnabled(Ref ref) {
  final settings = ref.watch(privacySettingsNotifierProvider).value;
  return settings?.isAppLockEnabled ?? false;
}
