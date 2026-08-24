/// 현장 보관(소프트 삭제) — 서버 `pcomplete == 2`.
bool placeIsArchived(int pcomplete) => pcomplete == 2;

/// 목록·정산에 쓸 현장 표시명. 보관 현장이면 `(삭제된 현장)`을 붙인다.
String formatPlaceDisplayName(
  String pname, {
  required int pcomplete,
}) {
  final name = pname.trim();
  if (name.isEmpty) {
    return placeIsArchived(pcomplete) ? '(삭제된 현장)' : '';
  }
  if (!placeIsArchived(pcomplete)) return name;
  if (name.contains('삭제된 현장')) return name;
  return '$name (삭제된 현장)';
}
