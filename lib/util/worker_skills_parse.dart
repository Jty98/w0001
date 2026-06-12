List<String> parseSpecialtyList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => '$e'.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return raw
        .split(RegExp(r'[,，、]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

/// API JSON(회원·인력·worker_profile 중첩)에서 스킬 필드 추출.
({String? primary, List<String> specialties}) parseWorkerSkillsFromMap(
  Map<String, dynamic> m,
) {
  String? primary = _pickPrimary(m);
  var specs = parseSpecialtyList(m['specialties'] ?? m['specialty']);

  final nested = m['worker_profile'] ?? m['workerProfile'];
  if (nested is Map<String, dynamic>) {
    primary ??= _pickPrimary(nested);
    if (specs.isEmpty) {
      specs = parseSpecialtyList(nested['specialties'] ?? nested['specialty']);
    }
  }

  final linkedHuman = m['human'] ?? m['linked_human'] ?? m['linkedHuman'];
  if (linkedHuman is Map<String, dynamic>) {
    primary ??= _pickPrimary(linkedHuman);
    if (specs.isEmpty) {
      specs =
          parseSpecialtyList(linkedHuman['specialties'] ?? linkedHuman['specialty']);
    }
  }

  return (primary: primary, specialties: specs);
}

String? _pickPrimary(Map<String, dynamic> m) {
  final v = m['primary_specialty'] ?? m['primarySpecialty'];
  if (v is String && v.trim().isNotEmpty) return v.trim();
  return null;
}
