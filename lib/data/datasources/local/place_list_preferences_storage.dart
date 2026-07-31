import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:w0001/domain/place_list_display.dart';
import 'package:w0001/enums.dart';

/// 현장 관리 탭 — 탭(진행/완료)·정렬·즐겨찾기 로컬 설정.
class PlaceListLocalPreferences {
  const PlaceListLocalPreferences({
    this.placeState = PlaceState.incomplete,
    this.sortMode = PlaceListSortMode.startNewest,
    this.favoritePids = const [],
  });

  final PlaceState placeState;
  final PlaceListSortMode sortMode;
  final List<int> favoritePids;

  PlaceListLocalPreferences copyWith({
    PlaceState? placeState,
    PlaceListSortMode? sortMode,
    List<int>? favoritePids,
  }) {
    return PlaceListLocalPreferences(
      placeState: placeState ?? this.placeState,
      sortMode: sortMode ?? this.sortMode,
      favoritePids: favoritePids ?? this.favoritePids,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'place_state': placeState.name,
        'sort_mode': sortMode.name,
        'favorite_pids': favoritePids,
      };

  static PlaceListLocalPreferences fromJson(Map<String, dynamic> json) {
    PlaceState tab = PlaceState.incomplete;
    final tabRaw = json['place_state']?.toString();
    if (tabRaw != null) {
      tab = PlaceState.values.firstWhere(
        (e) => e.name == tabRaw,
        orElse: () => PlaceState.incomplete,
      );
    }

    PlaceListSortMode sort = PlaceListSortMode.defaultFor(tab);
    final sortRaw = json['sort_mode']?.toString();
    if (sortRaw != null) {
      sort = PlaceListSortMode.values.firstWhere(
        (e) => e.name == sortRaw,
        orElse: () => PlaceListSortMode.defaultFor(tab),
      );
    }

    final favRaw = json['favorite_pids'];
    final favs = <int>[];
    if (favRaw is List) {
      for (final e in favRaw) {
        final id = e is int ? e : int.tryParse(e.toString());
        if (id != null && id > 0) favs.add(id);
      }
    }

    return PlaceListLocalPreferences(
      placeState: tab,
      sortMode: sort,
      favoritePids: favs,
    );
  }
}

/// 계정(uid)별 현장 목록 UI 설정 캐시.
class PlaceListPreferencesStorage {
  static const _keyPrefix = 'place_list_prefs_v1_';

  String _keyFor(String uid) => '$_keyPrefix$uid';

  Future<PlaceListLocalPreferences> load(String uid) async {
    if (uid.trim().isEmpty) return const PlaceListLocalPreferences();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyFor(uid));
      if (raw == null) return const PlaceListLocalPreferences();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return PlaceListLocalPreferences.fromJson(data);
    } catch (_) {
      return const PlaceListLocalPreferences();
    }
  }

  Future<void> save(String uid, PlaceListLocalPreferences settings) async {
    if (uid.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(uid), jsonEncode(settings.toJson()));
  }

  Future<void> clear(String uid) async {
    if (uid.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(uid));
  }
}
