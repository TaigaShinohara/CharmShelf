import 'package:flutter_test/flutter_test.dart';

import '../../tool/performance_qa_package.dart';

void main() {
  const qaPackage = 'com.tsmusic.privateshelf.opensource.performanceqa';

  group('isolated performance QA packages', () {
    for (var length = 0; length <= 8; length++) {
      final instance = '12345678'.substring(0, length);
      test('accepts a $length-digit instance', () {
        expect(
          () => requirePerformanceQaPackage('$qaPackage$instance'),
          returnsNormally,
        );
      });
    }

    for (final instance in ['0', '00000000', '01234567', '99999999']) {
      test('accepts instance $instance allowed by Gradle', () {
        expect(
          () => requirePerformanceQaPackage('$qaPackage$instance'),
          returnsNormally,
        );
      });
    }
  });

  group('packages that must never receive fixtures', () {
    final invalidPackages = <String, String>{
      'former QA app': 'com.tsmusic.privateshelf.performanceqa',
      'normal app': 'com.tsmusic.privateshelf',
      'debug app': 'com.tsmusic.privateshelf.debug',
      'other app': 'com.example.other',
      'other app with QA suffix': 'com.example.other.performanceqa123',
      'wrong namespace': 'com.other.privateshelf.performanceqa123',
      'empty ID': '',
      'QA suffix only': 'performanceqa123',
      'partial QA suffix': 'com.tsmusic.privateshelf.performanceq',
      'prefixed ID': 'other.$qaPackage',
      'unescaped separators': 'comXtsmusicXprivateshelfXperformanceqa1',
      'extra package segment': '$qaPackage.1',
      'extra trailing suffix': '${qaPackage}1.debug',
      'nine digits': '${qaPackage}123456789',
      'nine zeroes': '${qaPackage}000000000',
      'letter suffix': '${qaPackage}a',
      'mixed suffix': '${qaPackage}12a3',
      'negative number': '$qaPackage-1',
      'positive sign': '$qaPackage+1',
      'underscore': '${qaPackage}_1',
      'fullwidth digit': '$qaPackage１',
      'Arabic-Indic digit': '$qaPackage١',
      'leading space': ' $qaPackage',
      'trailing space': '$qaPackage ',
      'trailing newline': '$qaPackage\n',
      'newline after number': '${qaPackage}123\n',
      'trailing CRLF': '${qaPackage}123\r\n',
      'embedded newline': '$qaPackage\n123',
      'trailing tab': '$qaPackage\t',
      'trailing NUL': '$qaPackage\u0000',
      'uppercase ID': qaPackage.toUpperCase(),
    };

    for (final entry in invalidPackages.entries) {
      test('rejects ${entry.key}', () {
        expect(
          () => requirePerformanceQaPackage(entry.value),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'Performance fixtures require the isolated QA package.',
            ),
          ),
        );
      });
    }
  });
}
