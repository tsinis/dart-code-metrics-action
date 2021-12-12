@TestOn('vm')
import 'package:action_app/package_utils.dart';
import 'package:test/test.dart';

void main() {
  group('package utils', () {
    test('validateFoldersToAnalyze returns only exists folders', () {
      expect(
        validateFoldersToAnalyze(['lib', 'bin', 'lib', 'resources'], '.'),
        unorderedEquals(<String>['bin', 'lib']),
      );
    });
  });
}
