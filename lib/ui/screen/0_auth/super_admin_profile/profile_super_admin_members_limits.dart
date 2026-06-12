/// 프로필 「회원 관리」목록 표시 상한.
abstract final class ProfileSuperAdminMembersLimits {
  /// 활동 회원 — 처음·더보기 단위.
  static const int activePageSize = 10;
  static const int activePageStep = 10;

  /// 승인 대기·정지·거절 각 섹션.
  static const int queuePageSize = 8;

  /// 이름 검색 결과가 많을 때 화면 상한.
  static const int searchResultCap = 25;
}
