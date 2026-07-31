import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:w0001/data/model/worker_rank_wage_settings.dart';

/// 역할별 기본 일당 로컬 캐시 (서버 미구현·오프라인 시에도 편집 가능).
class WorkerRankWageSettingsStorage {
  static const _key = 'worker_rank_wage_settings_v1';

  Future<void> save(WorkerRankWageSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }

  Future<WorkerRankWageSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return WorkerRankWageSettings.empty();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return WorkerRankWageSettings.fromJson(data);
    } catch (_) {
      return WorkerRankWageSettings.empty();
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
