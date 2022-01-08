import 'package:actions_toolkit_dart/core.dart';

import 'services/system_process_runner.dart';

void gitHubAuthSetup(String token, SystemProcessRunner processRunner) {
  if (token.isEmpty) {
    return;
  }

  startGroup(name: 'Configure GitHub Auth');

  final hosts = {
    'https://github.com/': 'https://x-access-token:$token@github.com/',
    'git@github.com:': 'https://x-access-token:$token@github.com/',
  };

  for (final host in hosts.entries) {
    final gitResult = processRunner.run(
      'git',
      arguments: [
        'config',
        '--global',
        'url.${host.value}.insteadOf',
        host.key,
      ],
    );

    debug(message: 'Rewrite any "${host.key}" to "${host.value}"');
    debug(message: 'return code ${gitResult.exitCode}');
  }

  endGroup();
}
