import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 내부 큰글씨 모드(시스템 글자 크기와 별개) 설정.
class LargeTextModeNotifier extends Notifier<bool> {
  static const _key = 'large_text_mode';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_key);
      if (saved == null) {
        state = false;
        await prefs.setBool(_key, false);
        return;
      }
      state = saved;
    } catch (_) {
      state = false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } catch (_) {
      // 저장 실패 시에도 현재 세션 상태는 유지한다.
    }
  }
}

final largeTextModeProvider = NotifierProvider<LargeTextModeNotifier, bool>(
  LargeTextModeNotifier.new,
);
