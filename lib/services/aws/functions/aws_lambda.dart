import '../../../core/config/app_settings.dart';
import '../guardrails/budget_guard.dart';

class AwsLambda {
  Future<Map<String, dynamic>> invoke(String functionName, Map<String, dynamic> payload) async {
    final settings = AppSettings();
    if (!settings.awsEnabled) return {'ok': false, 'reason': 'awsDisabled'};
    final guard = BudgetGuard();
    if (!guard.canConsumeOne()) return {'ok': false, 'reason': 'budgetCap'};

    // TODO: real API Gateway/Lambda
    guard.consumeOne();
    return {'ok': true};
  }
}
