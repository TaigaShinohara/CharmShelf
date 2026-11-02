import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/features/library/presentation/helpers/import_picker_notification_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImportPickerNotificationHelper', () {
    test(
      'showPickerNotification executes without throwing MissingPluginException',
      () async {
        await expectLater(
          showPickerNotification(title: 'タイトル', body: '本文'),
          completes,
        );
      },
    );

    test(
      'cancelPickerNotification executes without throwing MissingPluginException',
      () async {
        await expectLater(cancelPickerNotification(), completes);
      },
    );
  });
}
