@TestOn('vm')
import 'package:action_app/src/github_workflow_utils.dart';
import 'package:test/test.dart';

const path = '/project/lib/source.dart';
const message = 'simple message';

void main() {
  group('GitHubWorkflowUtils', () {
    test('currentCommitSHA returns run commit sha taken from head', () {
      expect(
        () {
          const GitHubWorkflowUtils(environmentVariables: {})
              .currentCommitSHA();
        },
        throwsArgumentError,
      );

      const branchHeadSHA = '1357908642';

      expect(
        const GitHubWorkflowUtils(
          environmentVariables: {'GITHUB_SHA': branchHeadSHA},
        ).currentCommitSHA(),
        equals(branchHeadSHA),
      );

//      expect(
//        verify(() => output.writeln(captureAny())).captured.single,
//        equals('::debug::SHA that triggered the workflow: 1357908642'),
//      );
    });

    test('currentPullRequestNumber returns null', () {
      expect(
        const GitHubWorkflowUtils(environmentVariables: {})
            .currentPullRequestNumber(),
        isNull,
      );
    });

    test('currentRepositorySlug returns defined slug of the repository', () {
      expect(
        () {
          const GitHubWorkflowUtils(environmentVariables: {})
              .currentRepositorySlug();
        },
        throwsArgumentError,
      );

      const slug = 'dart-code-checker/dart-code-metrics-action';

      expect(
        const GitHubWorkflowUtils(
          environmentVariables: {'GITHUB_REPOSITORY': slug},
        ).currentRepositorySlug(),
        equals(slug),
      );
    });

    test('currentPathToRepoRoot returns workspase path', () {
      expect(
        () {
          const GitHubWorkflowUtils(environmentVariables: {})
              .currentPathToRepoRoot();
        },
        throwsArgumentError,
      );

      const workspacePath = '/user/builder/repository';

      expect(
        const GitHubWorkflowUtils(
          environmentVariables: {'GITHUB_WORKSPACE': workspacePath},
        ).currentPathToRepoRoot(),
        equals(workspacePath),
      );
    });

    test('isTestMode returns true only for current repo', () {
      const slug = 'dart-code-checker/dart-code-metrics-action';

      expect(
        const GitHubWorkflowUtils(
          environmentVariables: {'GITHUB_REPOSITORY': slug},
        ).isTestMode(),
        isTrue,
      );

      expect(
        const GitHubWorkflowUtils(
          environmentVariables: {'GITHUB_REPOSITORY': 'slug'},
        ).isTestMode(),
        isFalse,
      );
    });
  });
}
