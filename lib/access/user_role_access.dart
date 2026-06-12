import 'package:w0001/data/model/auth_models.dart';

/// 앱 권한·네비게이션 기준 역할 묶음.
///
/// **관리자** ([UserRole.admin]): 경영·현장·회원 관리 UI.
/// **작업자** ([UserRole.worker]): 축소 탭·조회 위주 UX.
extension UserRoleAccess on UserRole {
  bool get isWorker => this == UserRole.worker;

  /// 관리자 앱 (`admin` 단일 역할).
  bool get isManagementRole => this == UserRole.admin;

  bool get isAdmin => this == UserRole.admin;

  /// 현장 문서 원본 보기 — `site`·`drawing`은 작업자 포함, `estimate`는 관리자만.
  bool canViewPlacePhotoDocuments(String photoType) {
    if (photoType == 'estimate') return isManagementRole;
    return isManagementRole || isWorker;
  }
}

/// [UserRead] 기준 편의 — 화면·VM에서 반복되는 `user.role.*` 정리.
extension UserReadAccess on UserRead {
  bool get isWorker => role.isWorker;

  bool get isManagementRole => role.isManagementRole;

  bool canViewPlacePhotoDocuments(String photoType) =>
      role.canViewPlacePhotoDocuments(photoType);

  bool get isPendingApproval =>
      role.isWorker && approvalStatus == UserApprovalStatus.pending;
}
