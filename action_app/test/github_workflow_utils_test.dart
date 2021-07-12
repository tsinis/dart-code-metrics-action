@TestOn('vm')
import 'dart:io';

import 'package:action_app/src/github_action_input.dart';
import 'package:action_app/src/github_workflow_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class IOSinkMock extends Mock implements IOSink {}

const path = '/project/lib/source.dart';
const message = 'simple message';

void main() {
  group('GitHubWorkflowUtils', () {
    // ignore: close_sinks
    late IOSinkMock output;

    setUp(() {
      output = IOSinkMock();
    });

    group('actionInputValue', () {
      late GitHubWorkflowUtils workflow;

      setUp(() {
        workflow = GitHubWorkflowUtils(
          environmentVariables: {
            'INPUT_GITHUB_TOKEN': '02468A',
            'INPUT_EMPTY': '',
          },
          output: output,
        );
      });

      test('throws ArgumentError for uninitialized input', () {
        expect(
          () {
            workflow.actionInputValue(const GitHubActionInput(
              'token',
              isRequired: true,
              canBeEmpty: false,
            ));
          },
          throwsArgumentError,
        );

        expect(
          () {
            workflow.actionInputValue(const GitHubActionInput(
              'token',
              isRequired: false,
              canBeEmpty: false,
            ));
          },
          throwsArgumentError,
        );

        expect(
          () {
            workflow.actionInputValue(const GitHubActionInput(
              'empty',
              isRequired: false,
              canBeEmpty: false,
            ));
          },
          throwsArgumentError,
        );
      });

      test('returns input value', () {
        expect(
          workflow.actionInputValue(const GitHubActionInput(
            'github token',
            isRequired: true,
            canBeEmpty: false,
          )),
          equals('02468A'),
        );

        expect(
          workflow.actionInputValue(const GitHubActionInput(
            'token',
            isRequired: false,
            canBeEmpty: true,
          )),
          isEmpty,
        );

        expect(
          workflow.actionInputValue(const GitHubActionInput(
            'empty',
            isRequired: true,
            canBeEmpty: true,
          )),
          isEmpty,
        );
      });
    });

    test('currentCommitSHA returns run commit sha taken from head', () {
      expect(
        () {
          GitHubWorkflowUtils(environmentVariables: {}, output: output)
              .currentCommitSHA();
        },
        throwsArgumentError,
      );

      const branchHeadSHA = '1357908642';

      expect(
        GitHubWorkflowUtils(
          environmentVariables: {'GITHUB_SHA': branchHeadSHA},
          output: output,
        ).currentCommitSHA(),
        equals(branchHeadSHA),
      );

      expect(
        verify(() => output.writeln(captureAny())).captured.single,
        equals('::debug::SHA that triggered the workflow: 1357908642'),
      );
    });

    test('currentPullRequestNumber returns null', () {
      expect(
        GitHubWorkflowUtils(environmentVariables: {}, output: output)
            .currentPullRequestNumber(),
        isNull,
      );
    });

    test('currentRepositorySlug returns defined slug of the repository', () {
      expect(
        () {
          GitHubWorkflowUtils(environmentVariables: {}, output: output)
              .currentRepositorySlug();
        },
        throwsArgumentError,
      );

      const slug = 'dart-code-checker/dart-code-metrics-action';

      expect(
        GitHubWorkflowUtils(
          environmentVariables: {'GITHUB_REPOSITORY': slug},
          output: output,
        ).currentRepositorySlug(),
        equals(slug),
      );
    });

    test('currentPathToRepoRoot returns workspase path', () {
      expect(
        () {
          GitHubWorkflowUtils(environmentVariables: {}, output: output)
              .currentPathToRepoRoot();
        },
        throwsArgumentError,
      );

      const workspacePath = '/user/builder/repository';

      expect(
        GitHubWorkflowUtils(
          environmentVariables: {'GITHUB_WORKSPACE': workspacePath},
          output: output,
        ).currentPathToRepoRoot(),
        equals(workspacePath),
      );
    });

    test('logDebugMessage logs passed message', () {
      GitHubWorkflowUtils(environmentVariables: {}, output: output)
        ..logDebugMessage('')
        ..logDebugMessage(message)
        ..logDebugMessage(message, file: path)
        ..logDebugMessage(message, line: 1)
        ..logDebugMessage(message, column: 2)
        ..logDebugMessage(message, file: path, line: 1, column: 2)
        ..logDebugMessage('');

      expect(
        verify(() => output.writeln(captureAny())).captured,
        equals([
          '::debug::simple message',
          '::debug file=/project/lib/source.dart::simple message',
          '::debug line=1::simple message',
          '::debug col=2::simple message',
          '::debug file=/project/lib/source.dart,line=1,col=2::simple message',
        ]),
      );
    });

    test('logErrorMessage logs passed message', () {
      GitHubWorkflowUtils(environmentVariables: {}, output: output)
        ..logErrorMessage('')
        ..logErrorMessage(message)
        ..logErrorMessage(message, file: path)
        ..logErrorMessage(message, line: 1)
        ..logErrorMessage(message, column: 2)
        ..logErrorMessage(message, file: path, line: 1, column: 2)
        ..logErrorMessage('');

      expect(
        verify(() => output.writeln(captureAny())).captured,
        equals([
          '::error::simple message',
          '::error file=/project/lib/source.dart::simple message',
          '::error line=1::simple message',
          '::error col=2::simple message',
          '::error file=/project/lib/source.dart,line=1,col=2::simple message',
        ]),
      );
    });

    test('logInfoMessage logs passed message', () {
      GitHubWorkflowUtils(environmentVariables: {}, output: output)
        ..logInfoMessage('')
        ..logInfoMessage(message)
        ..logInfoMessage('');

      expect(
        verify(() => output.writeln(captureAny())).captured,
        equals([message]),
      );
    });

    test('logWarningMessage logs passed message', () {
      GitHubWorkflowUtils(environmentVariables: {}, output: output)
        ..logWarningMessage('')
        ..logWarningMessage(message)
        ..logWarningMessage(message, file: path)
        ..logWarningMessage(message, line: 1)
        ..logWarningMessage(message, column: 2)
        ..logWarningMessage(message, file: path, line: 1, column: 2)
        ..logWarningMessage('');

      expect(
        verify(() => output.writeln(captureAny())).captured,
        equals([
          '::warning::simple message',
          '::warning file=/project/lib/source.dart::simple message',
          '::warning line=1::simple message',
          '::warning col=2::simple message',
          '::warning file=/project/lib/source.dart,line=1,col=2::simple message',
        ]),
      );
    });

    test('startLogGroup logs command about start grouping log messages', () {
      GitHubWorkflowUtils(environmentVariables: {}, output: output)
          .startLogGroup('group name');

      expect(
        verify(() => output.writeln(captureAny())).captured.single,
        equals('::group::group name'),
      );
    });

    test('endLogGroup logs command about end grouping log messages', () {
      GitHubWorkflowUtils(environmentVariables: {}, output: output)
          .endLogGroup();

      expect(
        verify(() => output.writeln(captureAny())).captured.single,
        equals('::endgroup::'),
      );
    });

    test('isTestMode returns true only for current repo', () {
      const slug = 'dart-code-checker/dart-code-metrics-action';

      expect(
        GitHubWorkflowUtils(
          environmentVariables: {'GITHUB_REPOSITORY': slug},
          output: output,
        ).isTestMode(),
        isTrue,
      );

      expect(
        GitHubWorkflowUtils(
          environmentVariables: {'GITHUB_REPOSITORY': 'slug'},
          output: output,
        ).isTestMode(),
        isFalse,
      );
    });
  });
}
