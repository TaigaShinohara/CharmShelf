import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show Notifier, NotifierProvider;
import '../preferences/app_preferences.dart';
import 'shared_preferences_provider.dart';

part 'tutorial_providers.g.dart';

@riverpod
class TutorialState extends _$TutorialState {
  @override
  FutureOr<Map<String, bool>> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final keys = prefs.getKeys().where(
      (k) => k.startsWith('tutorial.') && k.endsWith('.completed'),
    );

    final states = <String, bool>{};
    for (final key in keys) {
      final tutorialId = key.split('.')[1];
      states[tutorialId] = prefs.getBool(key) ?? false;
    }
    return states;
  }

  Future<void> complete(String tutorialId) async {
    final operation = ref.keepAlive();
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final key = 'tutorial.$tutorialId.completed';
      await prefs.setBool(key, true);

      if (!ref.mounted) return;
      final current = state.value ?? {};
      state = AsyncData({...current, tutorialId: true});
    } finally {
      operation.close();
    }
  }

  Future<void> resetAll() async {
    final operation = ref.keepAlive();
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final keys = prefs.getKeys().where(
        (key) =>
            (key.startsWith('tutorial.') && key.endsWith('.completed')) ||
            key.startsWith('feature_tooltip.') ||
            key == AppPreferences.onboardingCompletedKey ||
            key == AppPreferences.importPickerGuideDismissedKey,
      );

      for (final key in keys) {
        await prefs.remove(key);
      }

      if (ref.mounted) state = const AsyncData({});
    } finally {
      operation.close();
    }
  }

  Future<bool> isCompleted(String tutorialId) async {
    final keepAlive = ref.keepAlive();
    try {
      return (await future)[tutorialId] ?? false;
    } finally {
      keepAlive.close();
    }
  }
}

/// 設定から「その画面の上で」チュートリアルを開き直す依頼。
class TutorialReviewRequest {
  const TutorialReviewRequest({required this.id, required this.token});

  final String id;
  final int token;
}

class TutorialReviewRequestNotifier extends Notifier<TutorialReviewRequest?> {
  int _token = 0;

  @override
  TutorialReviewRequest? build() => null;

  void request(String id) {
    _token += 1;
    state = TutorialReviewRequest(id: id, token: _token);
  }

  void clear() => state = null;
}

final tutorialReviewRequestProvider =
    NotifierProvider<TutorialReviewRequestNotifier, TutorialReviewRequest?>(
      TutorialReviewRequestNotifier.new,
    );
