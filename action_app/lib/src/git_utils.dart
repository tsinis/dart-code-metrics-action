import 'dart:io';

import 'package:actions_toolkit_dart/core.dart';

void gitHubAuthSetup(String token) {
  if (token.isEmpty) {
    return;
  }

  startGroup(name: 'Configure GitHub Auth');

  final hosts = {
    'https://github.com/': 'https://x-access-token:$token@github.com/',
    'git@github.com:': 'https://x-access-token:$token@github.com/',
  };

  for (final host in hosts.entries) {
    final gitResult = Process.runSync('git', [
      'config',
      '--global',
      'url.${host.value}.insteadOf',
      host.key,
    ]);

    debug(message: 'Rewrite any "${host.key}" to "${host.value}"');
    debug(message: 'return code ${gitResult.exitCode}');
    debug(message: gitResult.stdout.toString());
    error(message: gitResult.stderr.toString());
  }

  endGroup();
}
