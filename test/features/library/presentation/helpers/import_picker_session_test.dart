import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/presentation/helpers/import_picker_session.dart';

void main() {
  test('連打は一回だけ開き、通知復帰後は購読を解放して再度開ける', () async {
    final session = ImportPickerSession();
    final returns = StreamController<void>.broadcast();
    addTearDown(returns.close);
    final native = Completer<String?>();
    var opened = 0;
    var hidden = 0;
    Future<String?> run(Future<String?> Function() pick) => session.run(
      pick: () {
        opened++;
        return pick();
      },
      showNotification: () async {},
      hideNotification: () async {
        hidden++;
      },
      returns: returns.stream,
    );
    final first = run(() => native.future);
    expect(await run(() async => 'duplicate'), isNull);
    expect(opened, 1);
    returns.add(null);
    expect(await first, isNull);
    expect(returns.hasListener, isFalse);
    expect(hidden, 1);
    native.complete('late result');
    expect(await run(() async => 'second'), 'second');
    expect(opened, 2);
    expect(hidden, 2);
    expect(returns.hasListener, isFalse);
  });

  test('ピッカー例外でも通知と購読を片付け、次の操作を許可する', () async {
    final session = ImportPickerSession();
    final returns = StreamController<void>.broadcast();
    addTearDown(returns.close);
    var hidden = 0;
    await expectLater(
      session.run<String>(
        pick: () async => throw StateError('picker failed'),
        showNotification: () async {},
        hideNotification: () async {
          hidden++;
        },
        returns: returns.stream,
      ),
      throwsStateError,
    );
    expect(hidden, 1);
    expect(returns.hasListener, isFalse);
    expect(
      await session.run<String>(
        pick: () async => 'retry',
        showNotification: () async {},
        hideNotification: () async {},
        returns: returns.stream,
      ),
      'retry',
    );
  });
}
