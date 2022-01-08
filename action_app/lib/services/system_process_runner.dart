import 'dart:io';

import 'package:actions_toolkit_dart/core.dart';

class SystemProcessRunner {
  ProcessResult run(
    String executable, {
    Iterable<String> arguments = const [],
    String? workingDirectory,
  }) {
    final executableString = '$executable ${arguments.join(' ')}'.trim();

    debug(message: 'Run process: $executableString');

    final result = Process.runSync(
      executable,
      arguments.toList(),
      workingDirectory: workingDirectory,
    );

    debug(message: 'process exit code: ${result.exitCode}');
    if (result.stdout != null) {
      debug(message: result.stdout.toString());
    }
    if (result.stderr != null) {
      error(message: result.stderr.toString());
    }

    return ProcessResult(
      executableString,
      result.exitCode,
      result.stdout,
      result.stderr,
    );
  }
}

/// The result of running a process.
class ProcessResult {
  final String execString;

  /// Exit code for the process.
  final int exitCode;

  /// Standard output from the process.
  ///
  /// The value used for the `stdoutEncoding` argument to `Process.run`
  /// determines the type. If `null` was used, this value is of type `List<int>`
  /// otherwise it is of type `String`.
  final Object? stdout;

  /// Standard error from the process.
  ///
  /// The value used for the `stderrEncoding` argument to `Process.run`
  /// determines the type. If `null` was used, this value is of type `List<int>`
  /// otherwise it is of type `String`.
  final Object? stderr;

  const ProcessResult(this.execString, this.exitCode, this.stdout, this.stderr);
}
