import 'dart:io';

import 'package:actions_toolkit_dart/core.dart';

import 'pubspec_utils.dart';

class PubUtils {
  final bool flutterPackage;

  const PubUtils({required this.flutterPackage});

  void getThePackageDependencies(PubSpecUtils pubSpecUtils, String rootFolder) {
    startGroup(
      name: 'Get the "${pubSpecUtils.packageName}" package dependencies',
    );

    final executable = flutterPackage ? 'flutter' : 'dart';
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
}
