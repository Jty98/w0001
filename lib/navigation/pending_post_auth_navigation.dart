import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _kPrefsPayload = 'pending_post_auth_fcm_payload_v1';

/// 로그아웃 상태에서 푸시(또는 딥링크)로 들어온 경우, 로그인 성공 후 이동할 FCM `data`를 잠시 보관한다.
final class PendingPostAuthNavigation {
  PendingPostAuthNavigation._();

  static Map<String, dynamic>? _memory;

  static Future<void> stash(Map<String, dynamic> payload) async {
    if (payload.isEmpty) return;
    final copy = Map<String, dynamic>.from(payload);
    copy['__pending_saved_at_ms'] = DateTime.now().millisecondsSinceEpoch;
    _memory = copy;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPrefsPayload, jsonEncode(copy));
  }

  static Future<void> clear() async {
    _memory = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kPrefsPayload);
  }

  /// 보관된 페이로드를 꺼내고 저장소에서 제거한다. TTL(15분) 초과 시 무시한다.
  static Future<Map<String, dynamic>?> take() async {
    final p = await SharedPreferences.getInstance();
    Map<String, dynamic>? raw;
    if (_memory != null) {
      raw = Map<String, dynamic>.from(_memory!);
      _memory = null;
      await p.remove(_kPrefsPayload);
    } else {
      final s = p.getString(_kPrefsPayload);
      if (s == null || s.isEmpty) return null;
      await p.remove(_kPrefsPayload);
      try {
        final d = jsonDecode(s);
        if (d is Map) raw = Map<String, dynamic>.from(d);
      } catch (_) {
        return null;
      }
    }
    if (raw == null || raw.isEmpty) return null;

    final savedMsRaw = raw['__pending_saved_at_ms'];
    raw.remove('__pending_saved_at_ms');
    final savedMs = switch (savedMsRaw) {
      int v => v,
      num v => v.toInt(),
      _ => null,
    };
    if (savedMs != null) {
      final age = DateTime.now().millisecondsSinceEpoch - savedMs;
      if (age > const Duration(minutes: 15).inMilliseconds) {
        return null;
      }
    }
    return raw.isEmpty ? null : raw;
  }
}
