import 'package:w0001/util/career_input.dart';

/// 현장 역할(`worker_rank`) 선택지. 빈 문자열 = 미선택.
const kWorkerRankOptions = ['감리', '반장', '기공', '준기공', '조공'];

/// GET/PUT `/users/me/worker-profile`
class WorkerProfileRead {
  const WorkerProfileRead({
    this.uid,
    this.primarySpecialty,
    this.workerRank = '',
    this.career = '',
  });

  final String? uid;
  final String? primarySpecialty;

  /// `''` 또는 [kWorkerRankOptions] 중 하나.
  final String workerRank;
  final String career;

  factory WorkerProfileRead.fromJson(Map<String, dynamic> m) {
    final primary = m['primary_specialty'] ?? m['primarySpecialty'];
    final rankRaw = m['worker_rank'] ?? m['workerRank'];
    final careerRaw = m['career'] ?? m['career_years'] ?? m['careerYears'];
    return WorkerProfileRead(
      uid: _optStr(m['uid']),
      primarySpecialty: primary is String && primary.trim().isNotEmpty
          ? primary.trim()
          : null,
      workerRank: rankRaw is String ? rankRaw.trim() : '',
      career: CareerInputUtils.parseWireField(careerRaw),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'primary_specialty': primarySpecialty ?? '',
        'worker_rank': workerRank,
        'career': CareerInputUtils.careerForApi(career),
      };
}

String? _optStr(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}
