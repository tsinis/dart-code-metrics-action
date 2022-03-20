import 'dart:async';
import 'dart:convert';
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

      return GitHubTask._(
        client,
        workflowUtils,
        checkRun,
        slug,
        arguments.publishReportAsComment,
      );
    } on GitHubError catch (e) {
      if (e.toString().contains('Resource not accessible by integration')) {
        warning(
          message:
              "It seems that this action doesn't have the required permissions to call the GitHub API with the token you gave. "
              "This can occur if this repository is a fork, as in that case GitHub reduces the GITHUB_TOKEN's permissions for security reasons. "
              'Consequently, no report will be made on GitHub.',
        );

        return GitHubTask._(client, workflowUtils, null, slug, false);
      }

      rethrow;
    }
  }

  final GitHub _client;
  final GitHubWorkflowUtils _workflowUtils;
  final CheckRun? _checkRun;
  final RepositorySlug _repositorySlug;
  final DateTime _startTime;
  final bool _reportInComment;

  CheckRunConclusion? _checkRunConclusion;
  Iterable<CheckRunOutput> _checkRunOutputs = [];
  String? _commentBody;

  GitHubTask._(
    this._client,
    this._workflowUtils,
    this._checkRun,
    this._repositorySlug,
    this._reportInComment,
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

        if (_reportInComment) {
          await _postComment();
        }
      }

      info(message: 'Check Run Id: ${run?.id}');
      info(message: 'Check Suite Id: ${run?.checkSuiteId}');
      info(message: 'Report posted at: ${run?.detailsUrl}');
    } on Exception catch (cause) {
      try {
        await _cancelCheckRun(cause);
      } on Exception catch (exception, stackTrace) {
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
    _checkRunOutputs = _prepareCheckRunOutputs(conclusion, output);
    _commentBody =
        _prepareCommentBody(conclusion, _checkRun?.name, _checkRunOutputs);
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

  Future<void> _postComment() async {
    final pullRequestNumber = _workflowUtils.currentPullRequestNumber();
    final commentBody = _commentBody;

    if (pullRequestNumber != null && commentBody != null) {
      final comments =
          await _getPreviousComment(pullRequestNumber, commentBody).toList();

      try {
        if (comments.isEmpty) {
          await _client.issues
              .createComment(_repositorySlug, pullRequestNumber, commentBody);
        } else {
          final firstCommentId = comments.first.id;
          if (firstCommentId != null) {
            await _client.issues
                .updateComment(_repositorySlug, firstCommentId, commentBody);
          }
        }
      } on Exception catch (cause) {
        error(message: 'exception: $cause');
      }
    }
  }

  Stream<IssueComment> _getPreviousComment(
    int pullRequestNumber,
    String currentComment,
  ) {
    final onlySymbolsRegex = RegExp('[^a-zA-Z]');
    final currentHeader = LineSplitter.split(currentComment)
        .first
        .replaceAll(onlySymbolsRegex, '')
        .toLowerCase();

    return _client.issues
        .listCommentsByIssue(_repositorySlug, pullRequestNumber)
        .where((comment) {
      final commentBody = comment.body;
      if (commentBody == null || commentBody.isEmpty) {
        return false;
      }

      final commentHeader = LineSplitter.split(commentBody)
          .first
          .replaceAll(onlySymbolsRegex, '')
          .toLowerCase();

      return commentHeader == currentHeader;
    });
  }

  Iterable<CheckRunOutput> _prepareCheckRunOutputs(
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

  String? _prepareCommentBody(
    CheckRunConclusion conclusion,
    String? checkRunName,
    Iterable<CheckRunOutput> outputs,
  ) {
    final buffer = StringBuffer();

    if (checkRunName != null) {
      var status = '⁉️';
      if (conclusion == CheckRunConclusion.success) {
        status = '✅';
      } else if (conclusion == CheckRunConclusion.failure) {
        status = '❌';
      }

      buffer.writeln('# $checkRunName $status');
    }

    if (outputs.isNotEmpty) {
      if (buffer.isNotEmpty) {
        buffer.writeln();
      }

      buffer.write(outputs.first.summary);

      final outputText = outputs.first.text;
      if (outputText != null && outputText.isNotEmpty) {
        if (buffer.isNotEmpty) {
          buffer.writeln();
        }

        buffer.write(outputText);
      }
    }

    return buffer.toString();
  }
}
