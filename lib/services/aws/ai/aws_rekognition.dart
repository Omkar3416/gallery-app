import '../../../core/config/app_settings.dart';
import '../guardrails/budget_guard.dart';

class AwsRekognition {
  Future<List<String>> detectLabels(String objectKey) async {
    final settings = AppSettings();
    if (!settings.awsEnabled) return const [];
    final guard = BudgetGuard();
    if (!guard.canConsumeOne()) return const [];

    // TODO: call Rekognition DetectLabels
    guard.consumeOne();
    return const ['label:cloud']; // placeholder
  }
}
