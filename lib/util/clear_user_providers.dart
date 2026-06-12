import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/worker_profile_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_personal_dashboard_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_schedule_notifier.dart';
import 'package:w0001/presentation/viewmodel/dashboard_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/calendar_view_model.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/user_notifications_providers.dart';
import 'package:w0001/presentation/viewmodel/user_account_providers.dart';
import 'package:w0001/presentation/viewmodel/user_private_providers.dart';

/// 로그아웃 또는 사용자 변경 시 모든 사용자별 provider를 초기화합니다.
/// 
/// 이 함수는 다음과 같은 경우에 호출됩니다:
/// - 로그아웃 시
/// - 다른 계정으로 로그인했을 때
/// - 사용자 세션이 변경되었을 때
void clearAllUserProviders(ProviderContainer container) {
  try {
    // 워커 관련 provider
    container.invalidate(workerProfileProvider);
    container.invalidate(workerPersonalDashboardProvider);
    container.invalidate(workerDashboardQueryProvider);
    container.invalidate(workerScheduleNotifierProvider);
    
    // 관리자 대시보드 관련 provider
    container.invalidate(dashboardProvider);
    container.invalidate(dashboardScheduleProvider);
    
    // 공통 provider
    container.invalidate(placeListProvider);
    container.invalidate(calendarProvider);
    container.invalidate(workerProvider);
    container.invalidate(userNotificationInboxProvider);
    container.invalidate(workerPrivateInfoProvider);
    container.invalidate(userAccountProvider);
    container.invalidate(workerTaxTermProvider);

    // 주의: authSessionProvider는 invalidate하지 않음
    // (로그인 시 loadCurrentUser()로 새로 로드됨)
  } catch (e) {
    // provider가 아직 생성되지 않았을 수 있음 (무시)
  }
}

/// WidgetRef를 사용하여 provider를 초기화합니다.
void clearAllUserProvidersWithRef(WidgetRef ref) {
  try {
    ref.invalidate(workerProfileProvider);
    ref.invalidate(workerPersonalDashboardProvider);
    ref.invalidate(workerDashboardQueryProvider);
    ref.invalidate(workerScheduleNotifierProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(dashboardScheduleProvider);
    ref.invalidate(placeListProvider);
    ref.invalidate(calendarProvider);
    ref.invalidate(workerProvider);
    ref.invalidate(userNotificationInboxProvider);
    ref.invalidate(workerPrivateInfoProvider);
    ref.invalidate(userAccountProvider);
    ref.invalidate(workerTaxTermProvider);
  } catch (e) {
    // provider가 아직 생성되지 않았을 수 있음 (무시)
  }
}
