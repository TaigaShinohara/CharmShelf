import 'package:flutter_test/flutter_test.dart';
import 'package:wakelock_plus/src/wakelock_plus_windows_plugin.dart';
import 'package:win32/win32.dart';

void main() {
  test(
    'typed execution-state flags enable and disable display inhibition',
    () async {
      final calls = <EXECUTION_STATE>[];
      final plugin = WakelockPlusWindowsPlugin(
        setThreadExecutionState: (flags) {
          calls.add(flags);
          return ES_CONTINUOUS;
        },
      );
      await plugin.toggle(enable: true);
      expect(await plugin.enabled, isTrue);
      expect(calls.first.has(ES_CONTINUOUS | ES_DISPLAY_REQUIRED), isTrue);
      await plugin.toggle(enable: false);
      expect(await plugin.enabled, isFalse);
      expect(calls.last, ES_CONTINUOUS);
    },
  );

  test('zero native result preserves the previous enabled state', () async {
    var result = const EXECUTION_STATE(0);
    final plugin = WakelockPlusWindowsPlugin(
      setThreadExecutionState: (_) => result,
    );
    await plugin.toggle(enable: true);
    expect(await plugin.enabled, isFalse);
    result = ES_CONTINUOUS;
    await plugin.toggle(enable: true);
    expect(await plugin.enabled, isTrue);
    result = const EXECUTION_STATE(0);
    await plugin.toggle(enable: false);
    expect(await plugin.enabled, isTrue);
  });
}
