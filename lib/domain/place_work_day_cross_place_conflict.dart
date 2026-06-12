import 'package:w0001/data/model/remote/super_admin_dtos.dart';

/// 같은 날 다른 현장에 이미 투입된 인력.
class CrossPlaceWorkDayConflict {
  const CrossPlaceWorkDayConflict({
    required this.hid,
    required this.humanName,
    required this.assignments,
  });

  final int hid;
  final String humanName;

  /// [pid]·현장명·역할(있으면).
  final List<({int pid, String placeName, String workrole})> assignments;
}

String normalizePlaceWorkDateKey(String raw) {
  final t = raw.trim();
  if (t.length >= 10) return t.substring(0, 10);
  return t;
}

/// [targetPid]·[workdateIso] 기준으로 [hids] 중 타 현장 배정이 있으면 반환.
List<CrossPlaceWorkDayConflict> findCrossPlaceWorkDayConflicts({
  required List<PlaceWorkDayRead> allRows,
  required int targetPid,
  required String workdateIso,
  required Iterable<int> hids,
  required Map<int, String> placeNameByPid,
  required Map<int, String> humanNameByHid,
}) {
  final dayKey = normalizePlaceWorkDateKey(workdateIso);
  final hidSet = hids.toSet();
  if (hidSet.isEmpty || dayKey.isEmpty) return const [];

  final byHid = <int, List<PlaceWorkDayRead>>{};
  for (final r in allRows) {
    if (r.pid == targetPid) continue;
    if (!hidSet.contains(r.hid)) continue;
    if (normalizePlaceWorkDateKey(r.workdate) != dayKey) continue;
    byHid.putIfAbsent(r.hid, () => []).add(r);
  }

  final out = <CrossPlaceWorkDayConflict>[];
  for (final hid in hidSet) {
    final rows = byHid[hid];
    if (rows == null || rows.isEmpty) continue;
    final seenPid = <int>{};
    final assignments = <({int pid, String placeName, String workrole})>[];
    for (final r in rows) {
      if (!seenPid.add(r.pid)) continue;
      final name = placeNameByPid[r.pid]?.trim();
      assignments.add((
        pid: r.pid,
        placeName: (name != null && name.isNotEmpty) ? name : '현장 #${r.pid}',
        workrole: r.workrole.trim(),
      ));
    }
    assignments.sort((a, b) => a.placeName.compareTo(b.placeName));
    final hn = humanNameByHid[hid]?.trim();
    out.add(
      CrossPlaceWorkDayConflict(
        hid: hid,
        humanName: (hn != null && hn.isNotEmpty) ? hn : '인력 #$hid',
        assignments: assignments,
      ),
    );
  }
  out.sort((a, b) => a.humanName.compareTo(b.humanName));
  return out;
}
