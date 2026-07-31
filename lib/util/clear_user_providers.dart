import 'dart:async' show unawaited;

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
import 'package:w0001/presentation/viewmodel/worker_announcement_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_paged_list_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_rank_wage_settings_providers.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_process_schedule_notifier.dart';
import 'package:w0001/presentation/viewmodel/place_site_guide_providers.dart';
import 'package:w0001/presentation/viewmodel/place_workforce_notifier.dart';
import 'package:w0001/presentation/viewmodel/human_work_detail_view_model.dart';
import 'package:w0001/presentation/viewmodel/worker_mgmt_view_model.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';

/// 로그아웃 또는 사용자 변경 시 모든 사용자별 provider를 초기화합니다.
///
/// 이 함수는 다음과 같은 경우에 호출됩니다:
/// - 로그아웃 시
/// - 다른 계정으로 로그인했을 때
/// - 사용자 세션이 변경되었을 때
void clearAllUserProviders(ProviderContainer container) {
  try {
    try {
      container.read(workerAnnouncementUseCaseProvider).clearCaches();
    } catch (_) {}

    try {
      unawaited(
        container
            .read(workerRankWageSettingsRepositoryProvider)
            .clearLocalCache(),
      );
    } catch (_) {}

    // 워커 관련 provider
    container.invalidate(workerProfileProvider);
    container.invalidate(workerPersonalDashboardProvider);
    container.invalidate(workerDashboardQueryProvider);
    container.invalidate(workerDashboardGlobalAnnouncementPreviewProvider);
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
    container.invalidate(workerRankWageSettingsProvider);
    container.invalidate(workerRankWageSettingsRepositoryProvider);

    // pid·hid 등 family 캐시 — 계정 전환 시 이전 현장 상세가 남지 않게 한다.
    container.invalidate(placeDetailProvider);
    container.invalidate(placeWorkforceProvider);
    container.invalidate(placeProcessScheduleProvider);
    container.invalidate(placeSiteGuideByPidProvider);
    container.invalidate(humanWorkDetailProvider);
    container.invalidate(workerMgmtHidVmProvider);
    container.invalidate(workerMgmtHumanDirectoryProvider);
    container.invalidate(workerMgmtConflictsHubProvider);
    container.invalidate(addCostProvider);

    // 주의: authSessionProvider는 invalidate하지 않음
    // (로그인 시 loadCurrentUser()로 새로 로드됨)
  } catch (e) {
    // provider가 아직 생성되지 않았을 수 있음 (무시)
  }
}

/// WidgetRef를 사용하여 provider를 초기화합니다.
void clearAllUserProvidersWithRef(WidgetRef ref) {
  try {
    try {
      ref.read(workerAnnouncementUseCaseProvider).clearCaches();
    } catch (_) {}

    try {
      unawaited(
        ref.read(workerRankWageSettingsRepositoryProvider).clearLocalCache(),
      );
    } catch (_) {}

    ref.invalidate(workerProfileProvider);
    ref.invalidate(workerPersonalDashboardProvider);
    ref.invalidate(workerDashboardQueryProvider);
    ref.invalidate(workerDashboardGlobalAnnouncementPreviewProvider);
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
    ref.invalidate(workerRankWageSettingsProvider);
    ref.invalidate(workerRankWageSettingsRepositoryProvider);

    ref.invalidate(placeDetailProvider);
    ref.invalidate(placeWorkforceProvider);
    ref.invalidate(placeProcessScheduleProvider);
    ref.invalidate(placeSiteGuideByPidProvider);
    ref.invalidate(humanWorkDetailProvider);
    ref.invalidate(workerMgmtHidVmProvider);
    ref.invalidate(workerMgmtHumanDirectoryProvider);
    ref.invalidate(workerMgmtConflictsHubProvider);
    ref.invalidate(addCostProvider);
  } catch (e) {
    // provider가 아직 생성되지 않았을 수 있음 (무시)
  }
}
