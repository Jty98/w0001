/// 주특기·추가 작업 문자열이 동일 항목인지 (앞뒤 공백 제거, 영문 대소문자 무시).
bool workerSkillsTextEquals(String a, String b) {
  final x = a.trim();
  final y = b.trim();
  if (x.isEmpty || y.isEmpty) return false;
  return x.toLowerCase() == y.toLowerCase();
}

/// [skill]이 [primary] 대표 주특기와 겹치는지.
bool workerSkillDuplicatesPrimary(String skill, String primary) {
  return workerSkillsTextEquals(skill, primary);
}

/// 추가 작업 목록에서 대표 주특기와 같은 항목을 제외한다.
List<String> workerSkillsExtrasExcludingPrimary(
  Iterable<String> extras, {
  String? primary,
}) {
  final p = primary?.trim() ?? '';
  return extras
      .map((e) => e.trim())
      .where((e) {
        if (e.isEmpty) return false;
        if (p.isEmpty) return true;
        return !workerSkillDuplicatesPrimary(e, p);
      })
      .toList();
}
