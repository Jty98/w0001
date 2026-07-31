/// API JSON(회원·인력·worker_profile 중첩)에서 주특기 필드 추출.
String? parseWorkerPrimarySpecialtyFromMap(Map<String, dynamic> m) {
  String? primary = _pickPrimary(m);

  for (final key in ['worker_profile', 'workerProfile']) {
    final nested = m[key];
    if (nested is Map<String, dynamic>) {
      primary ??= _pickPrimary(nested);
    }
  }

  final linkedHuman = m['human'] ?? m['linked_human'] ?? m['linkedHuman'];
  if (linkedHuman is Map<String, dynamic>) {
    primary ??= _pickPrimary(linkedHuman);
  }

  return primary;
}

String? _pickPrimary(Map<String, dynamic> m) {
  final v = m['primary_specialty'] ?? m['primarySpecialty'];
  if (v is String && v.trim().isNotEmpty) return v.trim();
  return null;
}

/// API JSON에서 현장 역할(`worker_rank`) 추출.
String pickWorkerRankFromMap(Map<String, dynamic> m) {
  final top = m['worker_rank'] ?? m['workerRank'];
  if (top is String && top.trim().isNotEmpty) return top.trim();

  for (final key in ['worker_profile', 'workerProfile']) {
    final nested = m[key];
    if (nested is Map<String, dynamic>) {
      final v = nested['worker_rank'] ?? nested['workerRank'];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
  }
  return '';
}
