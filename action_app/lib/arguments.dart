import 'dart:io';

import 'package:actions_toolkit_dart/core.dart' as toolkit;
import 'package:path/path.dart' as p;

import 'github_workflow_utils.dart';
import 'package_path.dart';

const _defaultFolders = ['lib'];

const _pubspecYaml = 'pubspec.yaml';

class Arguments {
  /// Token to call the GitHub API.
  final String gitHubToken;

  /// Token for access to private repos on GitHub.
  final String gitHubPersonalAccessTokenKey;

  /// List of folders whose contents will be scanned.
  final Iterable<String> folders;

  /// Path of the package relatively to the root of the repository.
  final PackagePath packagePath;

  /// Is publish detailed report as commented directly into pull request.
  final bool publishReportAsComment;

  /// Configurable analyze report title pattern.
  final String analyzeReportTitlePattern;

  /// Treat warning level issues as fatal.
  final bool fatalWarnings;

  /// Treat performance level issues as fatal.
  final bool fatalPerformance;

  /// Treat style level issues as fatal.
  final bool fatalStyle;

  /// Is need to find unused files.
  final bool checkUnusedFiles;

  /// Folders whose contents will be scanned for find unused files.
  final Iterable<String> checkUnusedFilesFolders;

  /// Configurable unused files report title pattern.
  final String unusedFilesReportTitlePattern;

  /// Head SHA of the commit associated to the current workflow.
  final String commitSha;

  /// Slug of the repository.
  final String repositorySlug;

  factory Arguments(GitHubWorkflowUtils workflowUtils) {
    final packageRelativePath = toolkit.getInput(name: 'relative_path');

    final packagePath = PackagePath(
      pathToRepoRoot: workflowUtils.currentPathToRepoRoot(),
      relativePath: packageRelativePath,
    );

    if (!Directory(packagePath.canonicalPackagePath).existsSync()) {
      throw ArgumentError.value(
        packagePath.canonicalPackagePath,
        packageRelativePath,
        "This directory doesn't exist in your repository",
      );
    }

    if (!File(p.join(packagePath.canonicalPackagePath, _pubspecYaml))
        .existsSync()) {
      throw ArgumentError.value(
        packagePath.canonicalPackagePath,
        packageRelativePath,
        "This directory doesn't contains Dart/Flutter package",
      );
    }

    final folders = _parseFoldersList(toolkit.getInput(name: 'folders'));

    final unusedFilesFolders =
        toolkit.getInput(name: 'check_unused_files_folders').isNotEmpty
            ? _parseFoldersList(
                toolkit.getInput(name: 'check_unused_files_folders'),
              )
            : folders;

    return Arguments._(
      gitHubToken: toolkit.getInput(
        name: 'github_token',
        options: const toolkit.InputOptions(required: true),
      ),
      gitHubPersonalAccessTokenKey: toolkit.getInput(name: 'github_pat'),
      folders: folders.isNotEmpty ? folders : _defaultFolders,
      packagePath: packagePath,
      publishReportAsComment:
          toolkit.getBooleanInput(name: 'pull_request_comment'),
      analyzeReportTitlePattern:
          toolkit.getInput(name: 'analyze_report_title_pattern'),
      fatalWarnings: toolkit.getBooleanInput(name: 'fatal_warnings'),
      fatalPerformance: toolkit.getBooleanInput(name: 'fatal_performance'),
      fatalStyle: toolkit.getBooleanInput(name: 'fatal_style'),
      checkUnusedFiles: toolkit.getBooleanInput(name: 'check_unused_files'),
      checkUnusedFilesFolders: unusedFilesFolders,
      unusedFilesReportTitlePattern:
          toolkit.getInput(name: 'unused_files_report_title_pattern'),
      commitSha: workflowUtils.currentCommitSHA(),
      repositorySlug: workflowUtils.currentRepositorySlug(),
    );
  }

  Arguments._({
    required this.gitHubToken,
    required this.gitHubPersonalAccessTokenKey,
    required this.folders,
    required this.packagePath,
    required this.publishReportAsComment,
    required this.analyzeReportTitlePattern,
    required this.fatalWarnings,
    required this.fatalPerformance,
    required this.fatalStyle,
    required this.checkUnusedFiles,
    required this.checkUnusedFilesFolders,
    required this.unusedFilesReportTitlePattern,
    required this.commitSha,
    required this.repositorySlug,
  });
}

Iterable<String> _parseFoldersList(String folders) => folders
    .split(',')
    .map((folder) => folder.trim())
    .where((folder) => folder.isNotEmpty)
    .toSet();
