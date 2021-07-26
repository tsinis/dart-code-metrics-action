import 'dart:io';

import 'package:actions_toolkit_dart/core.dart';
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

  final PackagePath packagePath;

  final Iterable<String> folders;

  factory Arguments(GitHubWorkflowUtils workflowUtils) {
    final packageRelativePath = getInput(name: 'relative_path');

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

    final folders = getInput(name: 'folders')
        .split(',')
        .map((folder) => folder.trim())
        .where((folder) => folder.isNotEmpty)
        .toSet();

    return Arguments._(
      checkUnusedFiles: getBooleanInput(name: 'check_unused_files'),
      gitHubToken: getInput(
        name: 'github_token',
        options: const InputOptions(required: true),
      ),
      gitHubPersonalAccessTokenKey: getInput(name: 'github_pat'),
      commitSha: workflowUtils.currentCommitSHA(),
      repositorySlug: workflowUtils.currentRepositorySlug(),
      packagePath: packagePath,
      folders: folders.isNotEmpty ? folders : _defaultFolders,
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
  });
}
