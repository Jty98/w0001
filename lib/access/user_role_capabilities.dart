import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/auth_models.dart';

export 'user_role_access.dart';

/// API·UI에서 허용할 동작. [UserRoleAccess]의 역할 묶음을 기준으로 정의한다.
///
/// 관리자(`admin`) 전용·공통 기능을 [isAdmin]으로 통일한다.
extension UserRoleCapabilities on UserRole {
  /// `GET` 대시보드 현장 요약(`/dashboard/places-info` 등).
  bool get canAccessDashboardPlacesInfo => isAdmin;

  // ——— 관리자 ———

  /// 하단 탭·상황판(경영 KPI 홈).
  bool get canUseManagementDashboardTab => isManagementRole;

  /// 금액 추가 탭.
  bool get canUseAddExpenseTab => isManagementRole;

  /// 인건비 탭.
  bool get canUseWorkCostTab => isManagementRole;

  /// 현장 금액(자재/인건비 등) 및 수익 화면에서 편집·삭제.
  bool get canEditPlaceLedger => isManagementRole;

  /// 현장 공정표 편집(기간·셀·공정 추가 등).
  bool get canEditProcessSchedule => isManagementRole;

  /// 캘린더 탭 비용 목록 편집·삭제.
  bool get canEditCalendarExpenses => isManagementRole;

  /// `/worker-management/*` — 작업자 메모·평가, 트러블 페어 UI.
  bool get canAccessWorkerManagementMenus => isAdmin;

  /// 작업자 공지 작성·수정 (`GET/POST/PATCH /worker-announcements`).
  bool get canManageWorkerAnnouncements => isManagementRole;

  /// 부가기능 콘텐츠(오늘의 명언, 현장 지식 사전) 관리.
  bool get canManageExtras => isManagementRole;

  /// 현장 문서(PDF·엑셀) 원본 보기·인쇄·표 복사 등.
  bool get canUsePlaceDocumentTools => isManagementRole;

  /// 회원·계정 관리 UI (프로필 [회원 관리] 등).
  bool get canManageMemberAccounts => isAdmin;

  /// 작업자 주민번호·계좌 전체 조회(reveal API).
  bool get canRevealWorkerPrivateInfo => isAdmin;
}
