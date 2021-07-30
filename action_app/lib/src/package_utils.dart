import 'dart:io';

import 'package:actions_toolkit_dart/core.dart';
import 'package:path/path.dart';

import 'pubspec_utils.dart';

void getPackageDependencies(PubSpecUtils pubSpecUtils, String rootFolder) {
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
