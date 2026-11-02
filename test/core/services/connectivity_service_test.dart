import 'package:flutter_test/flutter_test.dart';
import 'package:private_shelf/core/services/connectivity_service.dart';

void main() {
  group('ConnectionStatus', () {
    test('online と offline の2つの状態がある', () {
      expect(ConnectionStatus.values.length, 2);
      expect(ConnectionStatus.values, contains(ConnectionStatus.online));
      expect(ConnectionStatus.values, contains(ConnectionStatus.offline));
    });
  });

  // 注: ConnectivityServiceはプラットフォームAPIに依存するため、
  // 詳細なテストは統合テストで行う。ここでは型とenumのテストのみ。
}
