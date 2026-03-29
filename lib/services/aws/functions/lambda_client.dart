import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_settings.dart';
import '../guardrails/budget_guard.dart';

class LambdaClient {
  static final LambdaClient _i = LambdaClient._();
  LambdaClient._();
  factory LambdaClient() => _i;

  Future<Map<String, dynamic>> invoke(String op, Map<String, dynamic> payload) async {
    final cfg = AppSettings().cloudConfig;
    if (!cfg.isEnabled) return {'ok': false, 'reason': 'cloudDisabled'};

    final guard = BudgetGuard();
    if (!guard.canConsumeOne()) return {'ok': false, 'reason': 'budgetCap'};

    final url = Uri.parse('${cfg.lambdaBaseUrl}/$op'); // e.g. https://.../upsert_meta
    try {
      final res = await http.post(
        url,
        headers: {'content-type': 'application/json'},
        body: jsonEncode(payload),
      );
      guard.consumeOne();
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'ok': true, 'status': res.statusCode, 'data': jsonDecode(res.body.isNotEmpty ? res.body : '{}')};
      } else {
        return {'ok': false, 'status': res.statusCode, 'body': res.body};
      }
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }
}
