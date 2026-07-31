import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WorkerSupplySearchHistoryEntry {
  const WorkerSupplySearchHistoryEntry({
    required this.query,
    required this.searchedAtMs,
  });

  final String query;
  final int searchedAtMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'query': query,
        'searched_at_ms': searchedAtMs,
      };

  static WorkerSupplySearchHistoryEntry? tryFromJson(
      Map<String, dynamic> json) {
    final query = json['query']?.toString().trim() ?? '';
    if (query.isEmpty) return null;
    final rawMs = json['searched_at_ms'];
    final ms = rawMs is int ? rawMs : int.tryParse('$rawMs');
    if (ms == null || ms <= 0) return null;
    return WorkerSupplySearchHistoryEntry(query: query, searchedAtMs: ms);
  }
}

class WorkerSupplySearchHistoryStorage {
  static const _prefsKey = 'worker_supply_search_history_v1';
  static const maxItems = 20;

  Future<List<WorkerSupplySearchHistoryEntry>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <WorkerSupplySearchHistoryEntry>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final row = WorkerSupplySearchHistoryEntry.tryFromJson(
            Map<String, dynamic>.from(item));
        if (row == null) continue;
        out.add(row);
      }
      out.sort((a, b) => b.searchedAtMs.compareTo(a.searchedAtMs));
      return out.take(maxItems).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> remember(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final current = await readAll();
    final filtered =
        current.where((e) => e.query != trimmed).toList(growable: true);
    filtered.insert(
      0,
      WorkerSupplySearchHistoryEntry(
        query: trimmed,
        searchedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (filtered.length > maxItems) {
      filtered.removeRange(maxItems, filtered.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(filtered.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> remove(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final current = await readAll();
    final next =
        current.where((e) => e.query != trimmed).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }
}
