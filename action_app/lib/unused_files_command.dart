import 'package:dart_code_metrics/config.dart';
import 'package:dart_code_metrics/unused_files_analyzer.dart';
import 'package:github/github.dart';

import 'task.dart';

Future<void> unusedFiles(
  String packageName,
  String rootFolder,
  Iterable<String> foldersToAnalyze,
  GitHubCheckRunReporter reporter,
) async {
  final options = await analysisOptionsFromFilePath(rootFolder);
  final unusedFilesConfig = UnusedFilesConfig.fromAnalysisOptions(options);

  final report = await const UnusedFilesAnalyzer()
      .runCliAnalysis(foldersToAnalyze, rootFolder, unusedFilesConfig);

  final conclusion = report.isNotEmpty
      ? CheckRunConclusion.failure
      : CheckRunConclusion.success;

  reporter.report(
    conclusion: conclusion,
    output: CheckRunOutput(
      title: 'Unused files report result for $packageName',
      summary: _generateSummary(foldersToAnalyze, report),
      text: _generateDetails(report),
    ),
  );
}

String _generateSummary(
  Iterable<String> scannedFolders,
  Iterable<UnusedFilesFileReport> report,
) {
  final buffer = StringBuffer()
    ..writeln('## Summary')
    ..writeln();
  if (scannedFolders.isNotEmpty) {
    buffer.writeln(
      scannedFolders.length == 1
          ? '* Scanned package folder: ${scannedFolders.single}'
          : '* Scanned package folders: ${scannedFolders.join(', ')}',
    );
  }

  buffer.writeln(report.isEmpty
      ? '* No unused files found! ✅'
      : '* Found unused files: ${report.length} ⚠');

  return buffer.toString();
}

String? _generateDetails(Iterable<UnusedFilesFileReport> report) {
  if (report.isEmpty) {
    return null;
  }

  final buffer = StringBuffer()
    ..writeln('## Unused files:')
    ..writeln();
  for (final file in report) {
    buffer.writeln('* ${file.relativePath}');
  }

  return buffer.toString();
}
