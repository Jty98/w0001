import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 현장 **계약(마감) 종료일** — 공정표·그리드 연장으로 바뀌는 `pend`와 별도로 보관.
///
/// 사용자가 기간을 직접 수정하거나 현장을 등록할 때만 갱신합니다.
class PlaceContractDeadlineStorage {
  PlaceContractDeadlineStorage._();

  static const _prefsKey = 'place_contract_pend_v1';

  static Future<Map<int, String>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <int, String>{};
      decoded.forEach((key, value) {
        final pid = int.tryParse(key.toString());
        final iso = value?.toString().trim() ?? '';
        if (pid != null && pid > 0 && iso.isNotEmpty && iso != '0') {
          out[pid] = iso;
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<String?> read(int pid) async {
    final all = await readAll();
    return all[pid];
  }

  static Future<void> write(int pid, String contractPendIso) async {
    final iso = contractPendIso.trim();
    if (pid <= 0 || iso.isEmpty || iso == '0') return;
    final all = await readAll();
    all[pid] = iso;
    await _saveAll(all);
  }

  static Future<void> remove(int pid) async {
    if (pid <= 0) return;
    final all = await readAll();
    if (!all.containsKey(pid)) return;
    all.remove(pid);
    await _saveAll(all);
  }

  /// 저장값이 없으면 [fallbackPend]로 한 번만 시드(기존 현장 마이그레이션).
  static Future<String?> ensureBootstrapped({
    required int pid,
    required String fallbackPend,
  }) async {
    final existing = await read(pid);
    if (existing != null) return existing;
    final fb = fallbackPend.trim();
    if (fb.isEmpty || fb == '0') return null;
    await write(pid, fb);
    return fb;
  }

  static Future<void> _saveAll(Map<int, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = map.map((k, v) => MapEntry(k.toString(), v));
    await prefs.setString(_prefsKey, jsonEncode(encoded));
  }
}
