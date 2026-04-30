import 'package:w0001/data/model/auth_models.dart';

/// 클라이언트에서 API 호출·UI 노출을 맞추기 위한 역할별 허용 범위.
///
/// 서버 정책이 바뀌면 여기와 백엔드를 함께 조정합니다.
extension UserRoleCapabilities on UserRole {
  /// `GET` 대시보드 현장 요약(`/dashboard/places-info` 등) — 현재 super_admin 전용.
  bool get canAccessDashboardPlacesInfo => this == UserRole.superAdmin;
}
