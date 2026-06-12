/// 현장 역할(`worker_rank`) 선택지. 빈 문자열 = 미선택.
const kWorkerRankOptions = ['감리', '반장', '기공', '준기공', '조공'];

/// GET/PUT `/users/me/worker-profile`
class WorkerProfileRead {
  const WorkerProfileRead({
    this.uid,
    this.primarySpecialty,
    this.specialties = const [],
    this.workerRank = '',
    this.career = '',
  });

  final String? uid;
  final String? primarySpecialty;
  final List<String> specialties;

  /// `''` 또는 [kWorkerRankOptions] 중 하나.
  final String workerRank;
  final String career;

  factory WorkerProfileRead.fromJson(Map<String, dynamic> m) {
    final primary = m['primary_specialty'] ?? m['primarySpecialty'];
    final raw = m['specialties'] ?? m['specialty'];
    List<String> specs = const [];
    if (raw is List) {
      specs = raw.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
    }
    final rankRaw = m['worker_rank'] ?? m['workerRank'];
    final careerRaw = m['career'];
    return WorkerProfileRead(
      uid: _optStr(m['uid']),
      primarySpecialty: primary is String && primary.trim().isNotEmpty
          ? primary.trim()
          : null,
      specialties: specs,
      workerRank: rankRaw is String ? rankRaw.trim() : '',
      career: careerRaw is String ? careerRaw.trim() : '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'primary_specialty': primarySpecialty ?? '',
        'specialties': specialties,
        'worker_rank': workerRank,
        'career': career,
      };
}

String? _optStr(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}
