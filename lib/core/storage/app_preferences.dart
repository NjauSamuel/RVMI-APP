import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive app flags. The login token stays in [SecureTokenStore].
class AppPreferences {
  AppPreferences(this._prefs);

  static const _themeModeKey = 'rvmi.theme_mode';
  static const _tagOrderKey = 'rvmi.filter_tag_order';
  static const _leadingTagKey = 'rvmi.filter_leading_tag';

  final SharedPreferences _prefs;

  static Future<AppPreferences> create() async {
    return AppPreferences(await SharedPreferences.getInstance());
  }

  ThemeMode get themeMode {
    final value = _prefs.getString(_themeModeKey);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) {
    return _prefs.setString(_themeModeKey, mode.name);
  }

  /// Stable per-phone tag order. New tags are shuffled in once.
  List<int> get tagOrder {
    final raw = _prefs.getStringList(_tagOrderKey);
    if (raw == null) return const [];
    return [for (final value in raw) ?int.tryParse(value)];
  }

  Future<void> setTagOrder(List<int> ids) {
    return _prefs.setStringList(_tagOrderKey, [for (final id in ids) '$id']);
  }

  int? get leadingTagId => _prefs.getInt(_leadingTagKey);

  Future<void> setLeadingTagId(int id) => _prefs.setInt(_leadingTagKey, id);
}
