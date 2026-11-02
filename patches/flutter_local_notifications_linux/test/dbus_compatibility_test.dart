import 'package:dbus/dbus.dart';
import 'package:flutter_local_notifications_linux/src/helpers.dart';
import 'package:flutter_local_notifications_linux/src/model/hint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification hints preserve nested string/variant DBus values', () {
    final value = LinuxHintDictValue.stringVariant({
      'category': LinuxHintVariantValue(LinuxHintStringValue('transfer')),
      'resident': LinuxHintVariantValue(LinuxHintBoolValue(true)),
    }).toDBusValue();
    expect(value.signature, DBusSignature('a{sv}'));
    expect(value.asStringVariantDict(), {
      'category': DBusString('transfer'),
      'resident': DBusBoolean(true),
    });
  });

  test('actions and image-data hints retain array/struct wire signatures', () {
    final actions = LinuxHintArrayValue([
      LinuxHintStringValue('default'),
      LinuxHintStringValue('Open'),
    ]).toDBusValue();
    expect(actions.signature, DBusSignature('as'));
    expect(actions.asStringArray(), ['default', 'Open']);
    final image = LinuxHintStructValue([
      LinuxHintInt32Value(1),
      LinuxHintInt32Value(1),
      LinuxHintArrayValue([LinuxHintByteValue(255)]),
    ]).toDBusValue();
    expect(image.signature, DBusSignature('(iiay)'));
  });
}
