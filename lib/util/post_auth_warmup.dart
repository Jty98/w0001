import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/worker_personal_dashboard_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_rank_wage_settings_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_schedule_notifier.dart';

/// 로그인·자동 로그인으로 [authSessionProvider]에 사용자가 확정된 직후,
/// 탭/IndexedStack 타이밍과 무관하게 역할별 캐시 데이터를 한 번 채운다.
///
/// 화면 bootstrap·provider auth 리스너만으로는 안드로이드에서 조회가 누락되는 경우가 있어
/// [AuthSessionNotifier.loadCurrentUser] 성공 시점에 호출한다.
Future<void> warmUpUserScopedData(
    ProviderContainer container, UserRead user) async {
  if (user.isPendingApproval) return;
  final placeVm = container.read(placeListProvider.notifier);
  await placeVm.fetchAllPlace(force: true);

  if (user.isWorker) {
    await container.read(workerPersonalDashboardProvider.notifier).reload(
          silent: false,
        );
    // 홈 위젯에 현장투입·개인 일정 반영
    unawaited(
      container.read(workerScheduleNotifierProvider.notifier).reload(),
    );
    return;
  }

  unawaited(
    container.read(workerRankWageSettingsUseCaseProvider).warmUp(),
  );

  await Future.wait<void>([
    container.read(dashboardProvider.notifier).fetch(
          force: true,
          isWorker: user.isWorker,
        ),
    container
        .read(dashboardScheduleProvider.notifier)
        .ensureWeekLoaded(force: true),
  ]);
}

void scheduleWarmUpUserScopedData(ProviderContainer container, UserRead user) {
  unawaited(() async {
    try {
      await Future<void>.delayed(Duration.zero);
      await warmUpUserScopedData(container, user);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('warmUpUserScopedData failed: $e\n$st');
      }
    }
  }());
}
