import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/calendar_view_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_workforce_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_mgmt_view_model.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/util/worker_dashboard_refresh.dart';

/// [main]에서 [UncontrolledProviderScope]와 동일한 컨테이너를 할당해야 함
ProviderContainer? rootProviderContainer;

class FetchData {
  /// 레거시 전역 갱신. 신규 코드는 [onDataChanged] 사용.
  static Future<void> fetchAllData() async {
    await onDataChanged(
      const DataChangeEvent(DataChangeKind.workCost),
      background: false,
    );
  }

  /// 변경 종류에 맞춰 필요한 provider만 갱신한다.
  ///
  /// [background]가 `true`(기본)이면 호출자는 즉시 반환하고 갱신은 백그라운드에서 수행한다.
  static Future<void> onDataChanged(
    DataChangeEvent event, {
    bool background = true,
  }) async {
    final container = rootProviderContainer;
    if (container == null) return;

    final job = _dispatch(container, event);
    if (background) {
      unawaited(job);
      return;
    }
    await job;
  }

  static Future<void> _dispatch(
    ProviderContainer container,
    DataChangeEvent event,
  ) async {
    final u = container.read(authSessionProvider).asData?.value;
    final isWorker = u?.isWorker ?? false;

    switch (event.kind) {
      case DataChangeKind.workCost:
      case DataChangeKind.materialCost:
        await _refreshWorkAndMaterialCosts(container, event, isWorker);
        break;
      case DataChangeKind.place:
        await container.read(placeListProvider.notifier).fetchAllPlace();
        if (!isWorker) {
          await container
              .read(dashboardProvider.notifier)
              .fetch(isWorker: false);
        }
        break;
      case DataChangeKind.human:
        await container.read(workerProvider.notifier).refreshFromGlobalFetch();
        if (container.exists(workerMgmtHumanDirectoryProvider)) {
          await container
              .read(workerMgmtHumanDirectoryProvider.notifier)
              .reload(blocking: false);
        }
        break;
      case DataChangeKind.revenue:
        await _refreshPlaceDetailRevenue(container, event.pid);
        if (!isWorker) {
          await container
              .read(dashboardProvider.notifier)
              .fetch(isWorker: false);
        }
        break;
      case DataChangeKind.photo:
        await _refreshPlaceDetailPhotos(container, event.pid);
        break;
      case DataChangeKind.schedule:
        if (!isWorker) {
          await container.read(dashboardScheduleProvider.notifier).refresh();
        }
        break;
      case DataChangeKind.processSchedule:
        if (!isWorker) {
          await container
              .read(calendarProvider.notifier)
              .refreshCalendarMarkers();
        }
        await container.read(placeListProvider.notifier).fetchAllPlace();
        await _refreshPlaceDetail(container, event.pid);
        break;
    }
  }

  static Future<void> _refreshWorkAndMaterialCosts(
    ProviderContainer container,
    DataChangeEvent event,
    bool isWorker,
  ) async {
    final futures = <Future<void>>[];

    if (isWorker) {
      scheduleWorkerPersonalDashboardReload(container);
    } else if (event.refreshCalendar) {
      final cal = container.read(calendarProvider.notifier);
      futures.add(cal.fetchTotalCost());
      if (event.kind == DataChangeKind.workCost) {
        futures.add(cal.refreshCalendarMarkers());
      }
    }

    if (container.exists(workerProvider)) {
      futures.add(
        container
            .read(workerProvider.notifier)
            .refreshWorkCostsFromGlobalFetch(),
      );
    }

    futures.add(container.read(placeListProvider.notifier).fetchAllPlace());
    if (!isWorker) {
      futures.add(
        container.read(dashboardProvider.notifier).fetch(isWorker: false),
      );
    }

    futures.add(_refreshPlaceDetailCosts(container, event.pid));

    if (event.kind == DataChangeKind.workCost && event.pid != null) {
      final wf = placeWorkforceProvider(event.pid!);
      if (container.exists(wf)) {
        futures.add(container.read(wf.notifier).reload(silent: true));
      }
    }

    await Future.wait(futures);
  }

  static Future<void> _refreshPlaceDetailCosts(
    ProviderContainer container,
    int? pid,
  ) async {
    if (pid != null) {
      final d = placeDetailProvider(pid);
      if (container.exists(d)) {
        await container.read(d.notifier).refreshCostsForGlobalFetch();
      }
      return;
    }
    final places = container.read(placeListProvider).placeList;
    final tasks = <Future<void>>[];
    for (final p in places) {
      final id = p.pid;
      if (id == null) continue;
      final d = placeDetailProvider(id);
      if (!container.exists(d)) continue;
      tasks.add(container.read(d.notifier).refreshCostsForGlobalFetch());
    }
    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
    }
  }

  static Future<void> _refreshPlaceDetailRevenue(
    ProviderContainer container,
    int? pid,
  ) async {
    if (pid != null) {
      final d = placeDetailProvider(pid);
      if (container.exists(d)) {
        await container.read(d.notifier).refreshRevenueForGlobalFetch();
      }
      return;
    }
    final places = container.read(placeListProvider).placeList;
    for (final p in places) {
      final id = p.pid;
      if (id == null) continue;
      final d = placeDetailProvider(id);
      if (!container.exists(d)) continue;
      await container.read(d.notifier).refreshRevenueForGlobalFetch();
    }
  }

  static Future<void> _refreshPlaceDetailPhotos(
    ProviderContainer container,
    int? pid,
  ) async {
    if (pid != null) {
      final d = placeDetailProvider(pid);
      if (container.exists(d)) {
        await container.read(d.notifier).refreshPhotosForGlobalFetch();
      }
      return;
    }
    final places = container.read(placeListProvider).placeList;
    for (final p in places) {
      final id = p.pid;
      if (id == null) continue;
      final d = placeDetailProvider(id);
      if (!container.exists(d)) continue;
      await container.read(d.notifier).refreshPhotosForGlobalFetch();
    }
  }

  /// 수익·사진 등 비용 외 전체 현장 상세 갱신.
  static Future<void> _refreshPlaceDetail(
    ProviderContainer container,
    int? pid,
  ) async {
    if (pid != null) {
      final d = placeDetailProvider(pid);
      if (container.exists(d)) {
        await container.read(d.notifier).refreshForGlobalFetch();
      }
      return;
    }
    final places = container.read(placeListProvider).placeList;
    for (final p in places) {
      final id = p.pid;
      if (id == null) continue;
      final d = placeDetailProvider(id);
      if (!container.exists(d)) continue;
      await container.read(d.notifier).refreshForGlobalFetch();
    }
  }
}

const List<String> categoryList = [
  '식대',
  '숙박',
  '유류비',
  '철물',
  '목재',
  '금속',
  '전기',
  '조명',
  '페인트',
  '설비',
  '타일',
  '공조',
  '소방',
  '유리',
  '조경',
  '필름',
  '사인물',
  '철거',
  '청소',
  '기타주문제작',
  '기타경비',
  '개인경비',
];
