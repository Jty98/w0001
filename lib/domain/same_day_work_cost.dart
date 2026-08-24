/// 같은 인력·같은 날의 현장 투입 한 곳.
class SameDayPlaceRef {
  const SameDayPlaceRef({
    required this.pid,
    required this.name,
    this.workrole = '',
  });

  final int pid;
  final String name;
  final String workrole;
}

String personWorkDayKey(int hid, String dateKey) => '$hid|$dateKey';

/// pid 기준 중복 없이 현장명을 이어 붙인다. (`현장A, 현장B`)
String joinSameDayPlaceNames(Iterable<SameDayPlaceRef> places) {
  final seen = <int>{};
  final names = <String>[];
  final sorted = [...places]..sort((a, b) => a.name.compareTo(b.name));
  for (final p in sorted) {
    if (p.pid <= 0 || !seen.add(p.pid)) continue;
    final n = p.name.trim();
    if (n.isEmpty) continue;
    names.add(n);
  }
  return names.join(', ');
}

String joinSameDayWorkRoles(Iterable<SameDayPlaceRef> places) {
  final seen = <String>{};
  final roles = <String>[];
  for (final p in places) {
    final r = p.workrole.trim();
    if (r.isEmpty || !seen.add(r)) continue;
    roles.add(r);
  }
  return roles.join(', ');
}

/// 같은 날 여러 건이 있어도 금액은 합치지 않고 1공수(양수 1건)만 쓴다.
int firstPositiveAmount(Iterable<int> amounts) {
  for (final a in amounts) {
    if (a > 0) return a;
  }
  return 0;
}

void addSameDayPlace(
  Map<String, List<SameDayPlaceRef>> into, {
  required int hid,
  required String dateKey,
  required SameDayPlaceRef place,
}) {
  if (hid <= 0 || dateKey.isEmpty || place.pid <= 0) return;
  final list = into.putIfAbsent(personWorkDayKey(hid, dateKey), () => []);
  for (var i = 0; i < list.length; i++) {
    if (list[i].pid != place.pid) continue;
    if (list[i].workrole.trim().isEmpty && place.workrole.trim().isNotEmpty) {
      list[i] = SameDayPlaceRef(
        pid: list[i].pid,
        name: list[i].name.trim().isNotEmpty ? list[i].name : place.name,
        workrole: place.workrole,
      );
    }
    return;
  }
  list.add(place);
}
