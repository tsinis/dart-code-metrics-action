import 'dart:math';

import 'package:actions_toolkit_dart/core.dart';
import 'package:github/github.dart';

import 'arguments.dart';
import 'github_workflow_utils.dart';

const _homePage = 'https://dartcodemetrics.dev/docs/integrations/github-action';

abstract class Task<T> {
  Future<bool> run(Future<void> Function(T) function);
}

abstract class GitHubCheckRunReporter {
  void report({required CheckRunConclusion conclusion, CheckRunOutput? output});
}

// The Checks API limits the number of annotations to a maximum of 50 per API request.
const _apiLimit = 50;

class GitHubTask
    implements Task<GitHubCheckRunReporter>, GitHubCheckRunReporter {
  static Future<Task<GitHubCheckRunReporter>> create({
    required String checkRunNamePattern,
    required String packageName,
    required GitHubWorkflowUtils workflowUtils,
    required Arguments arguments,
  }) async {
    final client =
        GitHub(auth: Authentication.withToken(arguments.gitHubToken));
    final slug = RepositorySlug.full(arguments.repositorySlug);
    try {
      final id = Random().nextInt(1000).toString();

      debug(message: 'Id attributed to checkrun: $id');

      final checkRunName =
          checkRunNamePattern.replaceAll(r'$packageName', packageName);

      final checkRun = await client.checks.checkRuns.createCheckRun(
        slug,
        name: workflowUtils.isTestMode() ? '$checkRunName ($id)' : checkRunName,
        headSha: arguments.commitSha,
        detailsUrl: _homePage,
        externalId: id,
        status: CheckRunStatus.queued,
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
  Iterable<CheckRunOutput> _checkRunOutputs = [];

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

      CheckRun? run;

      if (_checkRunOutputs.isEmpty) {
        run = await _client.checks.checkRuns.updateCheckRun(
          _repositorySlug,
          _checkRun!,
          status: CheckRunStatus.completed,
          completedAt: DateTime.now(),
          conclusion: _checkRunConclusion,
        );
      } else {
        for (final output in _checkRunOutputs) {
          run = await _client.checks.checkRuns.updateCheckRun(
            _repositorySlug,
            _checkRun!,
            status: CheckRunStatus.completed,
            completedAt: DateTime.now(),
            conclusion: _checkRunConclusion,
            output: output,
          );
        }
      }

      info(message: 'Check Run Id: ${run?.id}');
      info(message: 'Check Suite Id: ${run?.checkSuiteId}');
      info(message: 'Report posted at: ${run?.detailsUrl}');
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
    _checkRunConclusion =
        _workflowUtils.isTestMode() ? CheckRunConclusion.neutral : conclusion;
    _checkRunOutputs = _prepareOutput(conclusion, output);
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

  Iterable<CheckRunOutput> _prepareOutput(
    CheckRunConclusion conclusion,
    CheckRunOutput? output,
  ) {
    if (output == null) {
      return [];
    }

    final summary = _workflowUtils.isTestMode()
        ? (StringBuffer()
              ..writeln('**THIS ACTION HAS BEEN EXECUTED IN TEST MODE.**')
              ..writeln('**Conclusion = `$conclusion`**')
              ..writeln(output.summary))
            .toString()
        : output.summary;

    final annotations = output.annotations;

    if (annotations == null || annotations.isEmpty) {
      return [
        CheckRunOutput(
          title: output.title,
          summary: summary,
          text: output.text,
          images: output.images,
        ),
      ];
    }

    return List.generate(
      annotations.length ~/ _apiLimit + 1,
      (index) => CheckRunOutput(
        title: output.title,
        summary: summary,
        text: output.text,
        annotations: annotations.sublist(
          index * _apiLimit,
          min((index + 1) * _apiLimit, annotations.length),
        ),
        images: output.images,
      ),
    );
  }
}
