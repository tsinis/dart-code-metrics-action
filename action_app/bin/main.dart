import 'dart:io';

import 'package:action_app/analyze_command.dart';
import 'package:action_app/arguments.dart';
import 'package:action_app/github_workflow_utils.dart';
import 'package:action_app/package_utils.dart';
import 'package:action_app/pubspec_utils.dart';
import 'package:action_app/task.dart';
import 'package:action_app/unused_files_command.dart';
import 'package:actions_toolkit_dart/core.dart';

Future<void> main() async {
  final workflowUtils =
      GitHubWorkflowUtils(environmentVariables: Platform.environment);

  try {
    final arguments = Arguments(workflowUtils);
    final rootFolder = arguments.packagePath.canonicalPackagePath;
    final pubspecUtils = readPubspec(rootFolder);

    getPackageDependencies(pubspecUtils, rootFolder);

    startGroup(name: 'Running Dart Code Metrics');

    final foldersToAnalyze =
        validateFoldersToAnalyze(arguments.folders, rootFolder);

    final tasks = [
      (await GitHubTask.create(
        checkRunNamePattern: arguments.analyzeReportTitlePattern,
        packageName: pubspecUtils.packageName,
        workflowUtils: workflowUtils,
        arguments: arguments,
      ))
          .run((reporter) => analyze(
                pubspecUtils.packageName,
                rootFolder,
                foldersToAnalyze,
                reporter,
                workflowUtils,
              )),
      if (arguments.checkUnusedFiles)
        (await GitHubTask.create(
          checkRunNamePattern: arguments.unusedFilesReportTitlePattern,
          packageName: pubspecUtils.packageName,
          workflowUtils: workflowUtils,
          arguments: arguments,
        ))
            .run((reporter) => unusedFiles(
                  pubspecUtils.packageName,
                  rootFolder,
                  foldersToAnalyze,
                  reporter,
                )),
    ];

    await Future.wait(tasks);

    endGroup();
    // ignore: avoid_catches_without_on_clauses
  } catch (exception, stackTrace) {
    error(message: '$exception\n$stackTrace');
  }
}
