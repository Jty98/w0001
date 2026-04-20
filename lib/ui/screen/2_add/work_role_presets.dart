/// 인건비 역할 칩 목록. 첫 항목은 항상 `직접입력`.
const kWorkRolePresets = <String>[
  '직접입력',
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
