import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/enums.dart';

/// 현장 관리 목록 정렬.
enum PlaceListSortMode {
  startNewest,
  startOldest,
  endNewest,
  endOldest;

  String get labelKo => switch (this) {
        PlaceListSortMode.startNewest => '시작일 최신순',
        PlaceListSortMode.startOldest => '시작일 오래된순',
        PlaceListSortMode.endNewest => '종료일 최신순',
        PlaceListSortMode.endOldest => '종료일 오래된순',
      };

  static PlaceListSortMode defaultFor(PlaceState tab) =>
      tab == PlaceState.complete
          ? PlaceListSortMode.endNewest
          : PlaceListSortMode.startNewest;

  static List<PlaceListSortMode> optionsFor(PlaceState tab) {
    if (tab == PlaceState.complete) {
      return const [
        PlaceListSortMode.endNewest,
        PlaceListSortMode.endOldest,
        PlaceListSortMode.startNewest,
        PlaceListSortMode.startOldest,
      ];
    }
    return const [
      PlaceListSortMode.startNewest,
      PlaceListSortMode.startOldest,
      PlaceListSortMode.endNewest,
      PlaceListSortMode.endOldest,
    ];
  }
}

DateTime? _parsePlaceDate(String raw) {
  final t = raw.trim();
  if (t.isEmpty || t == '0') return null;
  final d = DateTime.tryParse(t);
  if (d == null) return null;
  return DateTime(d.year, d.month, d.day);
}

int _compareDateDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

int _compareDateAsc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

int _comparePlaces(PlaceInfoModel a, PlaceInfoModel b, PlaceListSortMode mode) {
  final cmp = switch (mode) {
    PlaceListSortMode.startNewest =>
      _compareDateDesc(_parsePlaceDate(a.pstart), _parsePlaceDate(b.pstart)),
    PlaceListSortMode.startOldest =>
      _compareDateAsc(_parsePlaceDate(a.pstart), _parsePlaceDate(b.pstart)),
    PlaceListSortMode.endNewest =>
      _compareDateDesc(_parsePlaceDate(a.pend), _parsePlaceDate(b.pend)),
    PlaceListSortMode.endOldest =>
      _compareDateAsc(_parsePlaceDate(a.pend), _parsePlaceDate(b.pend)),
  };
  if (cmp != 0) return cmp;
  return (a.pid ?? 0).compareTo(b.pid ?? 0);
}

/// 즐겨찾기한 현장을 상단에 고정 ([favoritePids] 순서 유지).
List<PlaceInfoModel> pinFavoritePlacesFirst({
  required List<PlaceInfoModel> sorted,
  required List<int> favoritePids,
}) {
  if (favoritePids.isEmpty || sorted.isEmpty) return sorted;

  final byPid = <int, PlaceInfoModel>{
    for (final p in sorted)
      if (p.pid != null) p.pid!: p,
  };
  final favSet = favoritePids.toSet();
  final pinned = <PlaceInfoModel>[];
  for (final pid in favoritePids) {
    final place = byPid[pid];
    if (place != null) pinned.add(place);
  }
  final rest =
      sorted.where((p) => p.pid == null || !favSet.contains(p.pid)).toList();
  return [...pinned, ...rest];
}

/// 진행/완료 탭 · 이름 검색 · 정렬을 적용한 목록.
List<PlaceInfoModel> applyPlaceListDisplay({
  required List<PlaceInfoModel> all,
  required PlaceState tab,
  required String searchQuery,
  required PlaceListSortMode sortMode,
  List<int> favoritePids = const [],
  bool skipTabFilter = false,
  bool skipSearchFilter = false,
}) {
  final wantComplete = tab == PlaceState.complete ? 1 : 0;
  final q = searchQuery.trim().toLowerCase();

  var list = skipTabFilter
      ? all
      : all.where((p) => p.pcomplete == wantComplete).toList();

  if (!skipSearchFilter && q.isNotEmpty) {
    list = list
        .where(
          (p) =>
              p.pname.toLowerCase().contains(q) ||
              p.paddress.toLowerCase().contains(q),
        )
        .toList();
  }

  final sorted = List<PlaceInfoModel>.from(list)
    ..sort((a, b) => _comparePlaces(a, b, sortMode));
  return pinFavoritePlacesFirst(sorted: sorted, favoritePids: favoritePids);
}

int countPlacesForTab(List<PlaceInfoModel> all, PlaceState tab) {
  final wantComplete = tab == PlaceState.complete ? 1 : 0;
  return all.where((p) => p.pcomplete == wantComplete).length;
}
