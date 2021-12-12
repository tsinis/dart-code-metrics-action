import 'dart:io';

import 'package:actions_toolkit_dart/core.dart';
import 'package:path/path.dart';

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
