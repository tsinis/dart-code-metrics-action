FROM dkrutskikh/dart_code_metrics_action:v4

ENTRYPOINT ["dart", "run", "/action_app/bin/main.dart"]
