import 'dart:io';

import 'package:action_app/action_app.dart';
import 'package:actions_toolkit_dart/core.dart';
import 'package:dart_code_metrics/config.dart';
import 'package:dart_code_metrics/lint_analyzer.dart';
import 'package:dart_code_metrics/unused_files_analyzer.dart';

Future<void> main() async {
  final workflowUtils =
      GitHubWorkflowUtils(environmentVariables: Platform.environment);

  late final AnalyzeReporter analyzeReporter;
  late final UnusedFilesReporter unusedFilesFileReport;

  try {
    final arguments = Arguments(workflowUtils);

    gitHubAuthSetup(arguments.gitHubPersonalAccessTokenKey);

    analyzeReporter = await AnalyzeReporter.create(
      workflowUtils: workflowUtils,
      arguments: arguments,
    );
    unusedFilesFileReport = await UnusedFilesReporter.create(
      workflowUtils: workflowUtils,
      arguments: arguments,
    );

    final rootFolder = arguments.packagePath.canonicalPackagePath;
    final pubspecUtils = readPubspec(rootFolder);

    getPackageDependencies(pubspecUtils, rootFolder);

    await analyzeReporter.run();
    await unusedFilesFileReport.run();

    startGroup(name: 'Running Dart Code Metrics');

    final foldersToAnalyze =
        validateFoldersToAnalyze(arguments.folders, rootFolder);
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
