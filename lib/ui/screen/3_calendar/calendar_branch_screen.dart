import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/calendar_view_model.dart';
import 'package:w0001/ui/screen/3_calendar/calendar_screen.dart';
import 'package:w0001/ui/screen/3_calendar/worker_schedule_screen.dart';

/// `/calendar` 브랜치: 관리자는 기존 [CalendarScreen], 작업자는 [WorkerScheduleScreen].
///
/// 작업자에게 [calendarProvider]를 쓰지 않는다 — 저장소가 슈퍼관리자·대시보드 API에 묶여 있어
/// 무응답·재시도로 UI가 멈춘 것처럼 보일 수 있다.
class CalendarBranchScreen extends ConsumerWidget {
  const CalendarBranchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWorker = ref.watch(authSessionProvider).maybeWhen(
          data: (u) => u?.isWorker ?? false,
          orElse: () => false,
        );

    return isWorker
        ? const WorkerScheduleScreen()
        : _CalendarDataBootstrap(child: const CalendarScreen());
  }
}

class _CalendarDataBootstrap extends ConsumerStatefulWidget {
  const _CalendarDataBootstrap({required this.child});

  final Widget child;

  @override
  ConsumerState<_CalendarDataBootstrap> createState() =>
      _CalendarDataBootstrapState();
}

class _CalendarDataBootstrapState
    extends ConsumerState<_CalendarDataBootstrap> {
  var _scheduledLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scheduleCalendarLoad());
  }

  void _scheduleCalendarLoad({bool force = false}) {
    if (!mounted || _scheduledLoad) return;
    _scheduledLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduledLoad = false;
      _ensureCalendarLoaded(force: force);
    });
  }

  void _ensureCalendarLoaded({bool force = false}) {
    if (!mounted) return;
    final u = ref.read(authSessionProvider).asData?.value;
    if (u == null || u.isWorker) return;
    if (!force && ref.read(calendarProvider).hasLoadedOnce) return;
    unawaited(ref.read(calendarProvider.notifier).loadInitialData());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserRead?>>(authSessionProvider, (prev, next) {
      final u = next.asData?.value;
      if (u == null || u.isWorker) return;
      final prevUser = prev?.asData?.value;
      final accountChanged =
          prevUser == null || prevUser.uid != u.uid || prevUser.role != u.role;
      if (!accountChanged && ref.read(calendarProvider).hasLoadedOnce) {
        return;
      }
      _scheduleCalendarLoad(force: accountChanged);
    });
    return widget.child;
  }
}
