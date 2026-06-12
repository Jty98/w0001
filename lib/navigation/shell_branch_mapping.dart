/// [StatefulShellRoute.indexedStack] 브랜치 인덱스와 하단 탭 표시 순서 매핑.
///
/// 브랜치 순서는 [createAppRouter]의 `branches` 배열과 동일해야 합니다.
/// 0: 대시보드, 1: 현장, 2: 금액 추가, 3: 캘린더, 4: 인건비, 5: 프로필(루트), 6: 설정
/// 관리자: 대시보드 → 현장 → 금액 추가 → 캘린더 → 인건비 → 설정
const List<int> operatorShellBranchOrder = [0, 1, 2, 3, 4, 6];

/// 작업자: 대시보드 → 내 일정 → 현장 관리 → 설정
const List<int> workerShellBranchOrder = [0, 3, 1, 6];

int shellIndexToDisplayIndex(int shellIndex, bool workerLayout) {
  final order = workerLayout ? workerShellBranchOrder : operatorShellBranchOrder;
  final i = order.indexOf(shellIndex);
  return i < 0 ? 0 : i;
}

int displayIndexToShellIndex(int displayIndex, bool workerLayout) {
  final order = workerLayout ? workerShellBranchOrder : operatorShellBranchOrder;
  if (displayIndex < 0 || displayIndex >= order.length) return order.first;
  return order[displayIndex];
}
