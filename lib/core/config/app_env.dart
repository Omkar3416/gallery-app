/// Central flags to ensure zero AWS costs by default.
/// Flip these only when you intentionally want to use cloud features.
/// We will gate *every* AWS call behind these flags.
class AppEnv {
  /// Keep AWS completely disabled by default.
  static const bool awsEnabled = false;

  /// Allow on-device AI first (no cloud). Cloud AI will also respect [awsEnabled].
  static const bool aiEnabled = true;

  /// TODO: move to --dart-define in a later step, e.g.
  /// --dart-define=AWS_ENABLED=false --dart-define=AI_ENABLED=true
}
