import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager extends ValueNotifier<ThemeMode> {
  ThemeManager._() : super(ThemeMode.dark); // Default to dark
  static final ThemeManager instance = ThemeManager._();

  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('is_dark_theme') ?? true;
      value = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      // Fallback to dark on error
      value = ThemeMode.dark;
    }
  }

  Future<void> setTheme(bool isDark) async {
    value = isDark ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_theme', isDark);
    } catch (_) {
      // Ignore save error
    }
  }
}
