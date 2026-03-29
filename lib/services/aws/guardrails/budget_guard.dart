import 'package:shared_preferences/shared_preferences.dart';

/// Simple local guardrail to *prevent* any AWS usage unless explicitly enabled,
/// and to cap calls under ultra-low thresholds (default = 0).
class BudgetGuard {
  static final BudgetGuard _i = BudgetGuard._();
  BudgetGuard._();
  factory BudgetGuard() => _i;

  static const _kCallsMonth = 'aws_calls_month';
  static const _kCallsMonthReset = 'aws_calls_month_reset';
  static const _kMaxCallsPerMonth = 'aws_max_calls_month';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _maybeResetMonth();
    // default: block everything until user raises the cap in Settings
    _prefs.setInt(_kMaxCallsPerMonth, _prefs.getInt(_kMaxCallsPerMonth) ?? 0);
  }

  void _maybeResetMonth() {
    final now = DateTime.now();
    final stored = DateTime.tryParse(_prefs.getString(_kCallsMonthReset) ?? '');
    if (stored == null || stored.year != now.year || stored.month != now.month) {
      _prefs.setInt(_kCallsMonth, 0);
      _prefs.setString(_kCallsMonthReset, DateTime(now.year, now.month).toIso8601String());
    }
  }

  int get callsThisMonth => _prefs.getInt(_kCallsMonth) ?? 0;
  int get maxCallsPerMonth => _prefs.getInt(_kMaxCallsPerMonth) ?? 0;

  set maxCallsPerMonth(int v) => _prefs.setInt(_kMaxCallsPerMonth, v);

  /// Returns false if executing another call would exceed the cap.
  bool canConsumeOne() {
    _maybeResetMonth();
    return callsThisMonth + 1 <= maxCallsPerMonth;
  }

  void consumeOne() {
    final n = callsThisMonth + 1;
    _prefs.setInt(_kCallsMonth, n);
  }
}
