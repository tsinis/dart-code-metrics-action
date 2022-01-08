@TestOn('vm')
import 'package:action_app/package_utils.dart';
import 'package:action_app/pubspec.dart';
import 'package:action_app/services/system_process_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class PubspecMock extends Mock implements Pubspec {}

class SystemProcessRunnerMock extends Mock implements SystemProcessRunner {}

void main() {
  group('package utils', () {
    group('getPackageDependencies', () {
      late PubspecMock pubspecMock;
      late SystemProcessRunnerMock systemProcessRunnerMock;

      const workingDirectory = '/home/developer/project';

      setUp(() {
        pubspecMock = PubspecMock();
        systemProcessRunnerMock = SystemProcessRunnerMock();

        when(() => pubspecMock.packageName).thenReturn('test_package');

        when(() => systemProcessRunnerMock.run(
              any(),
              arguments: any(named: 'arguments'),
              workingDirectory: any(named: 'workingDirectory'),
            )).thenReturn(const ProcessResult('', 0, null, null));
      });

      test('for Dart package', () {
        when(() => pubspecMock.isFlutterPackage).thenReturn(false);

        getPackageDependencies(
          pubspecMock,
          workingDirectory,
          systemProcessRunnerMock,
        );

        verify(() => systemProcessRunnerMock.run(
              'dart',
              arguments: ['pub', 'get'],
              workingDirectory: workingDirectory,
            ));
      });

      test('for Flutter package', () {
        when(() => pubspecMock.isFlutterPackage).thenReturn(true);

        getPackageDependencies(
          pubspecMock,
          workingDirectory,
          systemProcessRunnerMock,
        );

        verify(() => systemProcessRunnerMock.run(
              'flutter',
              arguments: ['pub', 'get'],
              workingDirectory: workingDirectory,
            ));
      });

      test('throws StateError if pub get returns non zero code', () {
        when(() => pubspecMock.isFlutterPackage).thenReturn(true);

        when(() => systemProcessRunnerMock.run(
              any(),
              arguments: any(named: 'arguments'),
              workingDirectory: any(named: 'workingDirectory'),
            )).thenReturn(const ProcessResult('', 1, null, null));

        expect(
          () => getPackageDependencies(
            pubspecMock,
            workingDirectory,
            systemProcessRunnerMock,
          ),
          throwsStateError,
        );
      });
    });

    test('validateFoldersToAnalyze returns only exists folders', () {
      expect(
        validateFoldersToAnalyze(['lib', 'bin', 'lib', 'resources'], '.'),
        unorderedEquals(<String>['bin', 'lib']),
      );
    });
  });
}
