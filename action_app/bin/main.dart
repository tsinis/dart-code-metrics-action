import 'dart:io';

import 'package:action_app/action_app.dart';
import 'package:actions_toolkit_dart/core.dart';
import 'package:dart_code_metrics/config.dart';
import 'package:dart_code_metrics/lint_analyzer.dart';

Future<void> main() async {
  final workflowUtils =
      GitHubWorkflowUtils(environmentVariables: Platform.environment);

  final arguments = Arguments(workflowUtils);
  final reporter = await AnalyzeReporter.create(
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

    await reporter.run();

    startGroup(name: 'Running Dart Code Metrics');

    final foldersToAnalyze = arguments.folders;
    final options = await analysisOptionsFromFilePath(rootFolder);
    final config = LintConfig.fromAnalysisOptions(options);

    final lintAnalyzerReport = await const LintAnalyzer()
        .runCliAnalysis(foldersToAnalyze, rootFolder, config);

    await reporter.complete(
      pubspecUtils.packageName,
      foldersToAnalyze,
      lintAnalyzerReport,
    );

    endGroup();
  } on Exception catch (cause) {
    try {
      await reporter.cancel(cause: cause);
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
