import 'package:flutter/material.dart'; // NEW: for ThemeMode/Color
import 'package:gallery_app/core/config/cloud_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_env.dart';

/// Default: production is locked (no cloud UI).
/// When Developer Mode is ON, the lock is lifted and you can toggle cloud.
const bool kCloudLockByDefault = true;

class AppSettings {
  static final AppSettings _i = AppSettings._();
  AppSettings._();
  factory AppSettings() => _i;

  // ------- keys -------
  static const _kAwsEnabled = 'aws_enabled';
  static const _kAiEnabled  = 'ai_enabled';
  static const _kCloudMode  = 'cloud_mode';   // 'disabled' | 'localstack' | 'aws'
  static const _kLambdaUrl  = 'lambda_url';
  static const _kDevMode    = 'dev_mode';     // hidden developer options
  static const _kAppKey     = 'appKey';

  // NEW: Theme
  static const _kThemeMode  = 'theme_mode';   // 'system' | 'light' | 'dark'
  static const _kSeedColor  = 'theme_seed';   // int (Color.value)

  // A tiny notifier to rebuild UI (e.g., theme/nav reacting live)
  final ValueNotifier<int> changes = ValueNotifier<int>(0);
  void _notify() => changes.value++;

  late SharedPreferences _prefs;

  // Future<void> init() async {
  //   _prefs = await SharedPreferences.getInstance();
  // }

Future<void> init() async {
  _prefs = await SharedPreferences.getInstance();

  // Persist first-run defaults if not set
  if (!_prefs.containsKey(_kThemeMode)) {
    _prefs.setString(_kThemeMode, 'light'); // ✅ default Light
  }
  if (!_prefs.containsKey(_kSeedColor)) {
    _prefs.setInt(_kSeedColor, 0xFF0062FF); // optional: default Blue seed
  }
}



  /// Hidden developer options toggle (unlocked via long-press on Settings)
  bool get devMode => _prefs.getBool(_kDevMode) ?? false;
  set devMode(bool v) { _prefs.setBool(_kDevMode, v); _notify(); }

  /// Cloud lock is active in production unless Developer Mode is ON.
  bool get isCloudLocked => kCloudLockByDefault && !devMode;

  /// Cloud backup ON/OFF. When locked, always returns false and ignores writes.
  bool get awsEnabled {
    final stored = _prefs.getBool(_kAwsEnabled) ?? false;
    return isCloudLocked ? false : stored;
  }
  set awsEnabled(bool v) {
    if (isCloudLocked) return;
    _prefs.setBool(_kAwsEnabled, v);
    _notify();
  }

  bool get aiEnabled => (_prefs.getBool(_kAiEnabled) ?? AppEnv.aiEnabled);
  set aiEnabled(bool v) { _prefs.setBool(_kAiEnabled, v); _notify(); }

  CloudMode get cloudMode {
    final s = _prefs.getString(_kCloudMode) ?? 'disabled';
    switch (s) {
      case 'localstack': return CloudMode.localstack;
      case 'aws':       return CloudMode.aws;
      default:          return CloudMode.disabled;
    }
  }
  set cloudMode(CloudMode m) {
    final s = switch (m) {
      CloudMode.localstack => 'localstack',
      CloudMode.aws       => 'aws',
      _                   => 'disabled',
    };
    _prefs.setString(_kCloudMode, s);
    _notify();
  }

  String get lambdaUrl => _prefs.getString(_kLambdaUrl) ?? '';
  set lambdaUrl(String v) { _prefs.setString(_kLambdaUrl, v.trim()); _notify(); }

  String get appKey => _prefs.getString(_kAppKey) ?? '';
  set appKey(String v) { _prefs.setString(_kAppKey, v.trim()); _notify(); }

  CloudConfig get cloudConfig =>
      CloudConfig(mode: cloudMode, lambdaBaseUrl: lambdaUrl);

  // ---------- THEME ----------
  ThemeMode get themeMode {
    final s = _prefs.getString(_kThemeMode) ?? 'light';
    switch (s) {
      case 'light': return ThemeMode.light;
      case 'dark':  return ThemeMode.dark;
      default:      return ThemeMode.system;
    }
  }
  set themeMode(ThemeMode m) {
    final s = switch (m) {
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
      ThemeMode.system => 'system',
    };
    _prefs.setString(_kThemeMode, s);
    _notify();
  }

  // Default playful purple if never set
  static const int _defaultSeedValue = 0xFF0062FF;

  Color get seedColor =>
      Color(_prefs.getInt(_kSeedColor) ?? _defaultSeedValue);

  set seedColor(Color c) {
    _prefs.setInt(_kSeedColor, c.value);
    _notify();
  }

  /// Convenience for nav bar visibility elsewhere:
  bool get cloudAvailable => !isCloudLocked && awsEnabled;
}
