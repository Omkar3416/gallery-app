enum CloudMode { disabled, localstack, aws }

class CloudConfig {
  const CloudConfig({
    required this.mode,
    required this.lambdaBaseUrl,
  });

  final CloudMode mode;
  final String lambdaBaseUrl; // e.g. https://<function-id>.lambda-url.<region>.on.aws

  bool get isEnabled => mode != CloudMode.disabled && lambdaBaseUrl.isNotEmpty;

  CloudConfig copyWith({CloudMode? mode, String? lambdaBaseUrl}) => CloudConfig(
    mode: mode ?? this.mode,
    lambdaBaseUrl: lambdaBaseUrl ?? this.lambdaBaseUrl,
  );
}
