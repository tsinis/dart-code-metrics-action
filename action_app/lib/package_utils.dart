import 'dart:io';

import 'package:actions_toolkit_dart/core.dart';
import 'package:path/path.dart';

import 'pubspec.dart';
import 'services/system_process_runner.dart';

void getPackageDependencies(
  Pubspec pubspec,
  String rootFolder,
  SystemProcessRunner processRunner,
) {
  startGroup(name: 'Get the "${pubspec.packageName}" package dependencies');

  final result = processRunner.run(
    pubspec.isFlutterPackage ? 'flutter' : 'dart',
    arguments: ['pub', 'get'],
    workingDirectory: rootFolder,
  );

  endGroup();

  if (result.exitCode != 0) {
    throw StateError('${result.execString} - returns ${result.exitCode}');
  }
}

Iterable<String> validateFoldersToAnalyze(
  Iterable<String> folders,
  String rootFolder,
) =>
    folders.where((folder) {
      if (!Directory(normalize(join(rootFolder, folder))).existsSync()) {
        warning(message: 'Folder $folder not found in package.');

        return false;
      }

      return true;
    }).toSet();
