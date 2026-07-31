import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 자재비 탭 — 카테고리별 최근 입력 자재명 (최대 10개, 로컬).
class MaterialNameHistoryStorage {
  static const _prefsKey = 'material_name_history_v1';
  static const maxPerCategory = 10;

  Future<Map<String, List<String>>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, List<String>>{};
      for (final e in decoded.entries) {
        final key = e.key.toString().trim();
        if (key.isEmpty) continue;
        final v = e.value;
        if (v is! List) continue;
        final names = <String>[];
        for (final item in v) {
          final name = item.toString().trim();
          if (name.isEmpty) continue;
          if (!names.contains(name)) names.add(name);
        }
        if (names.isNotEmpty) out[key] = names.take(maxPerCategory).toList();
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<List<String>> readForCategory(String category) async {
    final all = await readAll();
    return List<String>.from(all[category.trim()] ?? const []);
  }

  Future<void> remember({
    required String category,
    required String name,
  }) async {
    final cat = category.trim();
    final trimmed = name.trim();
    if (cat.isEmpty || trimmed.isEmpty) return;

    final all = await readAll();
    final list = List<String>.from(all[cat] ?? const []);
    list.removeWhere((e) => e == trimmed);
    list.insert(0, trimmed);
    if (list.length > maxPerCategory) {
      list.removeRange(maxPerCategory, list.length);
    }
    all[cat] = list;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(all));
  }

  Future<void> remove({
    required String category,
    required String name,
  }) async {
    final cat = category.trim();
    final trimmed = name.trim();
    if (cat.isEmpty || trimmed.isEmpty) return;

    final all = await readAll();
    final list = List<String>.from(all[cat] ?? const []);
    final next = list.where((e) => e != trimmed).toList();
    if (next.isEmpty) {
      all.remove(cat);
    } else {
      all[cat] = next;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(all));
  }
}
