/// 금액 추가 화면 등에서 현장 목록을 나눌 때 사용.
enum CostPlacePickerFilter {
  /// 진행 + 완료 (삭제 제외)
  all,

  /// 진행중 (`pcomplete == 0`)
  inProgress,

  /// 완료 (`pcomplete == 1`)
  completed,
}

extension CostPlacePickerFilterQuery on CostPlacePickerFilter {
  /// 목록 API `pcomplete` — [all]은 서버에 보내지 않고 클라이언트에서 삭제(2)만 제외.
  int? get pcompleteQuery {
    switch (this) {
      case CostPlacePickerFilter.all:
        return null;
      case CostPlacePickerFilter.inProgress:
        return 0;
      case CostPlacePickerFilter.completed:
        return 1;
    }
  }

  bool matchesPlace(int pcomplete) {
    switch (this) {
      case CostPlacePickerFilter.all:
        return pcomplete == 0 || pcomplete == 1;
      case CostPlacePickerFilter.inProgress:
        return pcomplete == 0;
      case CostPlacePickerFilter.completed:
        return pcomplete == 1;
    }
  }
}
