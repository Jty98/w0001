import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_personal_dashboard_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_schedule_notifier.dart';
import 'package:w0001/util/fetch_data.dart';

/// 작업자 「내 근로 현황」·현장별 투입 금액 — `GET /worker/dashboard/summary` 재조회.
void scheduleWorkerPersonalDashboardReload(ProviderContainer? container) {
  final c = container ?? rootProviderContainer;
  if (c == null) return;
  final u = c.read(authSessionProvider).asData?.value;
  if (u == null || !u.isWorker) return;
  unawaited(c.read(workerPersonalDashboardProvider.notifier).reload());
}

/// 작업자 「내 일정」— 개인 메모 + `summary.work_days` 배정 목록 재조회.
void scheduleWorkerScheduleReload(ProviderContainer? container) {
  final c = container ?? rootProviderContainer;
  if (c == null) return;
  final u = c.read(authSessionProvider).asData?.value;
  if (u == null || !u.isWorker) return;
  unawaited(c.read(workerScheduleNotifierProvider.notifier).reload());
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
