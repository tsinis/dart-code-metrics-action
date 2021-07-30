import 'dart:io';

import 'package:action_app/action_app.dart';
import 'package:actions_toolkit_dart/core.dart';

Future<void> main() async {
  final workflowUtils =
      GitHubWorkflowUtils(environmentVariables: Platform.environment);

  try {
    final arguments = Arguments(workflowUtils);

    gitHubAuthSetup(arguments.gitHubPersonalAccessTokenKey);

    final rootFolder = arguments.packagePath.canonicalPackagePath;
    final pubspecUtils = readPubspec(rootFolder);

    getPackageDependencies(pubspecUtils, rootFolder);

    startGroup(name: 'Running Dart Code Metrics');

    final foldersToAnalyze =
        validateFoldersToAnalyze(arguments.folders, rootFolder);

    final tasks = [
      (await GitHubTask.create(
        checkRunName: 'Dart Code Metrics analyze report',
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
          checkRunName: 'Dart Code Metrics unused files report',
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
