@TestOn('vm')
import 'package:action_app/git_utils.dart';
import 'package:action_app/services/system_process_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class SystemProcessRunnerMock extends Mock implements SystemProcessRunner {}

void main() {
  group('gitHubAuthSetup', () {
    test('change git global config', () {
      final systemProcessRunnerMock = SystemProcessRunnerMock();

      when(() => systemProcessRunnerMock.run(
            any(),
            arguments: any(named: 'arguments'),
            workingDirectory: any(named: 'workingDirectory'),
          )).thenReturn(const ProcessResult('', 0, null, null));

      gitHubAuthSetup('01234567890', systemProcessRunnerMock);

      verify(() => systemProcessRunnerMock.run(
            'git',
            arguments: [
              'config',
              '--global',
              'url.https://x-access-token:01234567890@github.com/.insteadOf',
              'https://github.com/',
            ],
          ));

      verify(() => systemProcessRunnerMock.run(
            'git',
            arguments: [
              'config',
              '--global',
              'url.https://x-access-token:01234567890@github.com/.insteadOf',
              'git@github.com:',
            ],
          ));
    });

    test('nothing doing if token empty', () {
      final systemProcessRunnerMock = SystemProcessRunnerMock();

      gitHubAuthSetup('', systemProcessRunnerMock);

      verifyNever(() => systemProcessRunnerMock.run(
            any(),
            arguments: any(named: 'arguments'),
            workingDirectory: any(named: 'workingDirectory'),
          ));
    });
  });
}
