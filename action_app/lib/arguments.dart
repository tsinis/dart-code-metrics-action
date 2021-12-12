import 'dart:io';

import 'package:actions_toolkit_dart/core.dart' as toolkit;
import 'package:path/path.dart' as p;

import 'github_workflow_utils.dart';
import 'package_path.dart';

const _defaultFolders = ['lib'];

const _pubspecYaml = 'pubspec.yaml';

class Arguments {
  /// Is need to find unused files
  final bool checkUnusedFiles;

  /// Token to call the GitHub API
  final String gitHubToken;

  /// Token for access to private repos on GitHub
  final String gitHubPersonalAccessTokenKey;

  /// Head SHA of the commit associated to the current workflow
  final String commitSha;

  /// Slug of the repository
  final String repositorySlug;

  final Iterable<String> folders;

  final PackagePath packagePath;

  final String analyzeReportTitlePattern;

  final String unusedFilesReportTitlePattern;

  final bool pullRequestComment;

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

    final folders = toolkit
        .getInput(name: 'folders')
        .split(',')
        .map((folder) => folder.trim())
        .where((folder) => folder.isNotEmpty)
        .toSet();

    return Arguments._(
      checkUnusedFiles: toolkit.getBooleanInput(name: 'check_unused_files'),
      gitHubToken: toolkit.getInput(
        name: 'github_token',
        options: const toolkit.InputOptions(required: true),
      ),
      gitHubPersonalAccessTokenKey: toolkit.getInput(name: 'github_pat'),
      commitSha: workflowUtils.currentCommitSHA(),
      repositorySlug: workflowUtils.currentRepositorySlug(),
      packagePath: packagePath,
      folders: folders.isNotEmpty ? folders : _defaultFolders,
      analyzeReportTitlePattern:
          toolkit.getInput(name: 'analyze_report_title_pattern'),
      unusedFilesReportTitlePattern:
          toolkit.getInput(name: 'unused_files_report_title_pattern'),
      pullRequestComment: toolkit.getBooleanInput(name: 'pull_request_comment'),
    );
  }

  Arguments._({
    required this.checkUnusedFiles,
    required this.gitHubToken,
    required this.gitHubPersonalAccessTokenKey,
    required this.commitSha,
    required this.repositorySlug,
    required this.packagePath,
    required this.folders,
    required this.analyzeReportTitlePattern,
    required this.unusedFilesReportTitlePattern,
    required this.pullRequestComment,
  });
}
