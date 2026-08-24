import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 작업지시 빠른 입력에 쓰는 최근 문구.
class WorkInstructionRecentStorage {
  static const _key = 'work_instruction_recent_v1';
  static const _max = 8;

  Future<List<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> remember(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final next = [t, ...await load().then((v) => v.where((e) => e != t))];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(next.take(_max).toList(growable: false)),
    );
  }
}
