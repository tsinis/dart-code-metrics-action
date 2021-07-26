import 'dart:io';

import 'package:action_app/action_app.dart';
import 'package:actions_toolkit_dart/core.dart';
import 'package:dart_code_metrics/config.dart';
import 'package:dart_code_metrics/lint_analyzer.dart';
import 'package:dart_code_metrics/unused_files_analyzer.dart';

Future<void> main() async {
  final workflowUtils =
      GitHubWorkflowUtils(environmentVariables: Platform.environment);

  final arguments = Arguments(workflowUtils);
  final analyzeReporter = await AnalyzeReporter.create(
    workflowUtils: workflowUtils,
    arguments: arguments,
  );
  final unusedFilesFileReport = await UnusedFilesReporter.create(
    workflowUtils: workflowUtils,
    arguments: arguments,
  );

  if (arguments.gitHubPersonalAccessTokenKey.isNotEmpty) {
    gitHubAuthSetup(arguments.gitHubPersonalAccessTokenKey);
  }

  try {
    final rootFolder = arguments.packagePath.canonicalPackagePath;
    final pubspecUtils = readPubspec(rootFolder);

    _getTheTargetPackagesDependencies(pubspecUtils, rootFolder);

    await analyzeReporter.run();
    await unusedFilesFileReport.run();

    startGroup(name: 'Running Dart Code Metrics');

    final foldersToAnalyze = arguments.folders;
    final options = await analysisOptionsFromFilePath(rootFolder);
    final lintConfig = LintConfig.fromAnalysisOptions(options);

    final lintAnalyzerReport = await const LintAnalyzer()
        .runCliAnalysis(foldersToAnalyze, rootFolder, lintConfig);

    await analyzeReporter.complete(
      pubspecUtils.packageName,
      foldersToAnalyze,
      lintAnalyzerReport,
    );

    final unusedFilesConfig = UnusedFilesConfig.fromAnalysisOptions(options);

    final unusedFilesReport = await const UnusedFilesAnalyzer().runCliAnalysis(
      foldersToAnalyze,
      rootFolder,
      unusedFilesConfig,
    );

    await unusedFilesFileReport.complete(
      pubspecUtils.packageName,
      foldersToAnalyze,
      unusedFilesReport,
    );

    endGroup();
  } on Exception catch (cause) {
    try {
      await analyzeReporter.cancel(cause: cause);
      await unusedFilesFileReport.cancel(cause: cause);
      // ignore: avoid_catches_without_on_clauses
    } catch (exception, stackTrace) {
      error(message: '$exception\n$stackTrace');
    }
  }
}

void _getTheTargetPackagesDependencies(
  PubSpecUtils pubSpecUtils,
  String rootFolder,
) {
  startGroup(
    name: 'Get the "${pubSpecUtils.packageName}" package dependencies',
  );

  final executable = pubSpecUtils.isFlutterPackage ? 'flutter' : 'dart';
  final pubGetResult = Process.runSync(
    executable,
    ['pub', 'get'],
    workingDirectory: rootFolder,
  );

  debug(message: 'exit code: ${pubGetResult.exitCode}');
  debug(message: pubGetResult.stdout.toString());
  error(message: pubGetResult.stderr.toString());

  endGroup();

  if (pubGetResult.exitCode != 0) {
    throw StateError(
      '$executable pub get - returns ${pubGetResult.exitCode}',
    );
  }
}
