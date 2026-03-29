import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController i = ThemeController._();

  final List<Color> seeds = const [
    Color(0xFF6750A4), // M3 purple
    Color(0xFF006D77), // teal
    Color(0xFF0B5FFF), // blue
    Color(0xFFEA4335), // red
    Color(0xFF2E7D32), // green
    Color(0xFFFB8C00), // orange
    Color(0xFF7C4DFF), // deep purple
  ];

  late SharedPreferences _prefs;
  bool _ready = false;

  ThemeMode _mode = ThemeMode.system;
  int _seedIndex = 0;

  ThemeMode get mode => _mode;
  int get seedIndex => _seedIndex;
  Color get seedColor => seeds[_seedIndex];

  Future<void> load() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();
    _mode = ThemeMode.values[_prefs.getInt('theme_mode') ?? ThemeMode.system.index];
    _seedIndex = _prefs.getInt('theme_seed') ?? 0;
    _seedIndex = _seedIndex.clamp(0, seeds.length - 1);
    _ready = true;
    notifyListeners();
  }

  void setMode(ThemeMode m) {
    _mode = m;
    _prefs.setInt('theme_mode', m.index);
    notifyListeners();
  }

  void setSeed(int i) {
    _seedIndex = i.clamp(0, seeds.length - 1);
    _prefs.setInt('theme_seed', _seedIndex);
    notifyListeners();
  }
}
