import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_personal_dashboard_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_schedule_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_paged_list_notifier.dart';
import 'package:w0001/util/fetch_data.dart';

/// 작업자 「내 근로 현황」·현장별 투입 금액 — `GET /worker/dashboard/summary` 재조회.
void scheduleWorkerPersonalDashboardReload(
  ProviderContainer? container, {
  bool silent = true,
}) {
  final c = container ?? rootProviderContainer;
  if (c == null) return;
  final u = c.read(authSessionProvider).asData?.value;
  if (u == null || !u.isWorker) return;
  unawaited(
    c.read(workerPersonalDashboardProvider.notifier).reload(silent: silent),
  );
}

/// 작업자 「내 일정」— 개인 메모 + `summary.work_days` 배정 목록 재조회.
void scheduleWorkerScheduleReload(ProviderContainer? container) {
  final c = container ?? rootProviderContainer;
  if (c == null) return;
  final u = c.read(authSessionProvider).asData?.value;
  if (u == null || !u.isWorker) return;
  unawaited(c.read(workerScheduleNotifierProvider.notifier).reload());
}

/// 작업자 대시보드 「전체 공지」 미리보기 재조회.
void scheduleWorkerGlobalAnnouncementPreviewReload(
    ProviderContainer? container) {
  final c = container ?? rootProviderContainer;
  if (c == null) return;
  final u = c.read(authSessionProvider).asData?.value;
  if (u == null || !u.isWorker) return;
  unawaited(
    c
        .read(workerDashboardGlobalAnnouncementPreviewProvider.notifier)
        .reload(silent: true),
  );
}

/// 배정·작업지시 FCM 수신 시 대시보드·내 일정을 함께 갱신한다.
void scheduleWorkerPlaceWorkDayRefresh(ProviderContainer? container) {
  scheduleWorkerPersonalDashboardReload(container);
  scheduleWorkerScheduleReload(container);
}

void invalidateWorkerPersonalDashboard(ProviderContainer? container) {
  final c = container ?? rootProviderContainer;
  if (c == null) return;
  final u = c.read(authSessionProvider).asData?.value;
  if (u == null || !u.isWorker) return;
  c.invalidate(workerPersonalDashboardProvider);
}
