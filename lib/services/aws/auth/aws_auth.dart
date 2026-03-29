// lib/services/aws/auth/aws_auth.dart
import '../../../core/config/app_settings.dart';

/// No-op auth: only adds x-app-key if you set it in Settings.
/// Keep this abstraction — later you can swap with real Cognito.
class AwsAuth {
  Future<Map<String, String>> authHeaders() async {
    final k = AppSettings().appKey;
    return k.isEmpty ? {} : {'x-app-key': k};
  }
}
