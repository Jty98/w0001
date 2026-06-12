import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 다크모드 설정 Notifier
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _loadThemeMode();
    return ThemeMode.light;
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_key);

      if (savedMode == null) {
        state = ThemeMode.light;
        await prefs.setString(_key, ThemeMode.light.name);
        return;
      }

      final loaded = ThemeMode.values.firstWhere(
        (mode) => mode.name == savedMode,
        orElse: () => ThemeMode.light,
      );

      // 기기 설정(system)은 UI와 실제 테마가 어긋날 수 있어 라이트로 통일한다.
      if (loaded == ThemeMode.system) {
        state = ThemeMode.light;
        await prefs.setString(_key, ThemeMode.light.name);
        return;
      }

      state = loaded;
    } catch (e) {
      state = ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (e) {
      // 저장 실패해도 메모리 상태는 변경됨
    }
  }

  Future<void> toggleDarkMode(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}

/// 테마 모드 Provider
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
