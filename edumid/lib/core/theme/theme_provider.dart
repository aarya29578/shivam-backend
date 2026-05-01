import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton [ChangeNotifier] that owns the current [ThemeMode] and persists
/// the user's preference via shared_preferences.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider._();
  static final ThemeProvider instance = ThemeProvider._();

  static const _key = 'dark_mode';

  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  /// Call once in [main] before [runApp].
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = (prefs.getBool(_key) ?? false) ? ThemeMode.dark : ThemeMode.light;
    // no notifyListeners here — app hasn't started yet
  }

  /// Toggle between light and dark and persist the choice.
  Future<void> toggle() async {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _mode == ThemeMode.dark);
  }
}
