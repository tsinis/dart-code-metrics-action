import 'dart:math';

import 'package:actions_toolkit_dart/core.dart';
import 'package:github/github.dart';

import 'arguments.dart';
import 'github_workflow_utils.dart';

const _homePage = 'https://dartcodemetrics.dev/';

abstract class Task<T> {
  Future<bool> run(Future<void> Function(T) function);
}

abstract class GitHubCheckRunReporter {
  void report({required CheckRunConclusion conclusion, CheckRunOutput? output});
}

class GitHubTask
    implements Task<GitHubCheckRunReporter>, GitHubCheckRunReporter {
  static Future<Task<GitHubCheckRunReporter>> create({
    required String checkRunName,
    required GitHubWorkflowUtils workflowUtils,
    required Arguments arguments,
  }) async {
    final client =
        GitHub(auth: Authentication.withToken(arguments.gitHubToken));
    final slug = RepositorySlug.full(arguments.repositorySlug);
    try {
      final id = Random().nextInt(1000).toString();

      debug(message: 'Id attributed to checkrun: $id');

      final checkRun = await client.checks.checkRuns.createCheckRun(
        slug,
        name: workflowUtils.isTestMode() ? '$checkRunName ($id)' : checkRunName,
        headSha: arguments.commitSha,
        status: CheckRunStatus.queued,
        detailsUrl: _homePage,
        externalId: id,
      );

      return GitHubTask._(client, workflowUtils, checkRun, slug);
    } on GitHubError catch (e) {
      if (e.toString().contains('Resource not accessible by integration')) {
        warning(
          message:
              "It seems that this action doesn't have the required permissions to call the GitHub API with the token you gave. "
              "This can occur if this repository is a fork, as in that case GitHub reduces the GITHUB_TOKEN's permissions for security reasons. "
              'Consequently, no report will be made on GitHub.',
        );

        return GitHubTask._(client, workflowUtils, null, slug);
      }

      rethrow;
    }
  }

  final GitHub _client;
  final GitHubWorkflowUtils _workflowUtils;
  final CheckRun? _checkRun;
  final RepositorySlug _repositorySlug;
  final DateTime _startTime;

  CheckRunConclusion? _checkRunConclusion;
  CheckRunOutput? _checkRunOutput;

  GitHubTask._(
    this._client,
    this._workflowUtils,
    this._checkRun,
    this._repositorySlug,
  ) : _startTime = DateTime.now();

  @override
  Future<bool> run(
    Future<void> Function(GitHubCheckRunReporter) function,
  ) async {
    if (_checkRun == null) {
      return false;
    }

    try {
      await _client.checks.checkRuns.updateCheckRun(
        _repositorySlug,
        _checkRun!,
        startedAt: _startTime,
        status: CheckRunStatus.inProgress,
      );

      await function(this);

      final run = await _client.checks.checkRuns.updateCheckRun(
        _repositorySlug,
        _checkRun!,
        status: CheckRunStatus.completed,
        completedAt: DateTime.now(),
        conclusion: _checkRunConclusion,
        output: _checkRunOutput,
      );

      info(message: 'Check Run Id: ${run.id}');
      info(message: 'Check Suite Id: ${run.checkSuiteId}');
      info(message: 'Report posted at: ${run.detailsUrl}');
    } on Exception catch (cause) {
      try {
        await _cancelCheckRun(cause);
        // ignore: avoid_catches_without_on_clauses
      } catch (exception, stackTrace) {
        error(message: '$exception\n$stackTrace');
      }

      return false;
    }

    return true;
  }

  @override
  void report({
    required CheckRunConclusion conclusion,
    CheckRunOutput? output,
  }) {
    _checkRunConclusion = conclusion;
    _checkRunOutput = output;

    if (_workflowUtils.isTestMode()) {
      _checkRunConclusion = CheckRunConclusion.neutral;

      if (output != null) {
        final summary = StringBuffer()
          ..writeln('**THIS ACTION HAS BEEN EXECUTED IN TEST MODE.**')
          ..writeln('**Conclusion = `$conclusion`**')
          ..writeln(output.summary);

        _checkRunOutput = CheckRunOutput(
          title: output.title,
          summary: summary.toString(),
          text: output.text,
          annotations: output.annotations,
          images: output.images,
        );
      }
    }
  }

  Future<void> _cancelCheckRun(Exception cause) async {
    debug(message: "Checkrun cancelled. Conclusion is 'CANCELLED'.");

    await _client.checks.checkRuns.updateCheckRun(
      _repositorySlug,
      _checkRun!,
      startedAt: _startTime,
      completedAt: DateTime.now(),
      status: CheckRunStatus.completed,
      conclusion: _workflowUtils.isTestMode()
          ? CheckRunConclusion.neutral
          : CheckRunConclusion.cancelled,
      output: CheckRunOutput(
        title: _checkRun?.name ?? '',
        summary:
            'This check run has been cancelled, due to the following error:'
            '\n\n```\n$cause\n```\n\n'
            'Check your logs for more information.',
      ),
    );
  }
}
