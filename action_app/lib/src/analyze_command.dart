import 'package:dart_code_metrics/config.dart';
import 'package:dart_code_metrics/lint_analyzer.dart';
import 'package:github/github.dart';

import 'github_checkrun_utils.dart';
import 'github_workflow_utils.dart';
import 'task.dart';

const _sourceLinesOfCodeMetricId = 'source-lines-of-code';
const _cyclomaticComplexityMetricId = 'cyclomatic-complexity';

Future<void> analyze(
  String packageName,
  String rootFolder,
  Iterable<String> foldersToAnalyze,
  GitHubCheckRunReporter reporter,
  GitHubWorkflowUtils workflowUtils,
) async {
  final options = await analysisOptionsFromFilePath(rootFolder);
  final lintConfig = LintConfig.fromAnalysisOptions(options);

  final checkRunUtils = GitHubCheckRunUtils(workflowUtils);

  final report = await const LintAnalyzer()
      .runCliAnalysis(foldersToAnalyze, rootFolder, lintConfig);

  final conclusion = report.any((file) => [
            ...file.antiPatternCases,
            ...file.issues,
          ].any((issue) => issue.severity != Severity.none))
      ? CheckRunConclusion.failure
      : CheckRunConclusion.success;

  reporter.report(
    conclusion: conclusion,
    output: CheckRunOutput(
      title: 'Analysis report for $packageName',
      summary: _generateSummary(foldersToAnalyze, report),
      annotations: report
          .map(
            (file) => [...file.issues, ...file.antiPatternCases].map(
              (issue) => checkRunUtils.issueToAnnotation(file.path, issue),
            ),
          )
          .expand((issues) => issues)
          .toList(),
    ),
  );
}

String _generateSummary(
  Iterable<String> scannedFolders,
  Iterable<LintFileReport> report,
) {
  final issuesCount = report.fold<int>(
    0,
    (prevValue, fileReport) =>
        prevValue +
        fileReport.issues.length +
        fileReport.antiPatternCases.length,
  );

  final totalSLOC = report.fold<num>(
    0,
    (prevValue, fileReport) =>
        prevValue +
        fileReport.functions.values.fold(
          0,
          (prevValue, functionReport) =>
              prevValue +
              (functionReport.metric(_sourceLinesOfCodeMetricId)?.value ?? 0),
        ),
  );

  final totalClasses = report.fold<int>(
    0,
    (prevValue, fileReport) => prevValue + fileReport.classes.keys.length,
  );

  final totalFunctions = report.fold<int>(
    0,
    (prevValue, fileReport) => prevValue + fileReport.functions.keys.length,
  );

  final totalCyclomatic = report.fold<num>(
    0,
    (prevValue, fileReport) =>
        prevValue +
        fileReport.functions.values.fold(
          0,
          (prevValue, functionReport) =>
              prevValue +
              (functionReport.metric(_cyclomaticComplexityMetricId)?.value ??
                  0),
        ),
  );

  final buffer = StringBuffer()..writeln('## Summary')..writeln();
  if (scannedFolders.isNotEmpty) {
    buffer.writeln(
      scannedFolders.length == 1
          ? '* Scanned package folder: ${scannedFolders.single}'
          : '* Scanned package folders: ${scannedFolders.join(', ')}',
    );
  }

  buffer
    ..writeln('* Total scanned files: ${report.length}')
    ..writeln('* Total lines of source code: $totalSLOC')
    ..writeln('* Total classes: $totalClasses')
    ..writeln()
    ..writeln(
      '* Average Cyclomatic Number per line of code: ${(totalCyclomatic / totalSLOC).toStringAsFixed(2)}',
    )
    ..writeln(
      '* Average Source Lines of Code per method: ${totalSLOC ~/ totalFunctions}',
    )
    ..writeln('* Found issues: $issuesCount ${issuesCount > 0 ? '⚠' : '✅'}');

  return buffer.toString();
}
