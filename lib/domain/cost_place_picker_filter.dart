/// 금액 추가 화면 등에서 현장 목록을 나눌 때 사용.
enum CostPlacePickerFilter {
  /// 진행 + 완료 (삭제 제외)
  all,
  /// 진행중 (`pcomplete == 0`)
  inProgress,
  /// 완료 (`pcomplete == 1`)
  completed,
}
