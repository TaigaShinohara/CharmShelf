import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dip_action_log.dart';
import '../dip_feature.dart';

/// ロケールのProvider
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>(
  (ref) => LocaleNotifier(),
);

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _load();
  }

  static const _key = 'dip_locale';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale != null) {
      await prefs.setString(_key, locale.languageCode);
    } else {
      await prefs.remove(_key);
    }
  }
}

/// 言語切り替え機能
class LocaleSwitchFeature extends DipFeature {
  @override
  String get id => 'locale_switch';

  @override
  String get title => '言語切り替え';

  @override
  String? get subtitle => '日本語/英語';

  @override
  IconData get icon => Icons.language;

  @override
  DipFeatureCategory get category => DipFeatureCategory.ui;

  @override
  bool get showInSettings => true;

  @override
  void onTap(BuildContext context) {
    // 何もしない（タイルで直接切り替え）
  }

  @override
  Widget buildTile(BuildContext context, {VoidCallback? onClose}) {
    return Consumer(
      builder: (context, ref, _) {
        final locale = ref.watch(localeProvider);
        final theme = Theme.of(context);

        return ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: Text(_getLocaleLabel(locale)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LocaleButton(
                label: '自動',
                isSelected: locale == null,
                onPressed: () => _setLocale(ref, null),
              ),
              const SizedBox(width: 4),
              _LocaleButton(
                label: '日本語',
                isSelected: locale?.languageCode == 'ja',
                onPressed: () => _setLocale(ref, const Locale('ja')),
              ),
              const SizedBox(width: 4),
              _LocaleButton(
                label: 'EN',
                isSelected: locale?.languageCode == 'en',
                onPressed: () => _setLocale(ref, const Locale('en')),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getLocaleLabel(Locale? locale) {
    if (locale == null) return 'システム設定';
    return switch (locale.languageCode) {
      'ja' => '日本語',
      'en' => 'English',
      _ => locale.languageCode,
    };
  }

  void _setLocale(WidgetRef ref, Locale? locale) {
    ref.read(localeProvider.notifier).setLocale(locale);
    DipActionLog.info('言語変更: ${_getLocaleLabel(locale)}', tag: 'UI');
  }
}

class _LocaleButton extends StatelessWidget {
  const _LocaleButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: isSelected ? theme.colorScheme.primaryContainer : null,
        foregroundColor: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
        minimumSize: const Size(48, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
