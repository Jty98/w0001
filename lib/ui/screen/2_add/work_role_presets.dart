/// 작업지시 없이 금액추가 탭에서만 넣을 때 기본 공정 라벨.
const kWorkRoleManualAddDefault = '기타';

/// 인건비 역할 칩 목록. 첫 항목은 항상 `직접입력`.
const kWorkRolePresets = <String>[
  '직접입력',
  '기타',
  '다기능공',
  '전기',
  '목수',
  '철거',
  '설비',
  '페인트',
  '사인물',
  '금속',
  '조공',
];

bool isWorkRoleInPresetList(String? role) =>
    role != null && kWorkRolePresets.contains(role);

/// 역할 수정 UI 초기값. `(선택된 칩 라벨, 직접입력 필드 초기값)`.
/// 비어 있으면 `(null, '')`, 프리셋이면 `(해당 라벨, '')`, 그 외는 `('직접입력', 원문)`.
(String? chip, String customInitial) workRolePresetInitialSelection(
  String wrole,
) {
  final t = wrole.trim();
  if (t.isEmpty) return (null, '');
  final fixed = kWorkRolePresets.where((e) => e != '직접입력').toSet();
  if (fixed.contains(t)) return (t, '');
  return ('직접입력', wrole);
}
