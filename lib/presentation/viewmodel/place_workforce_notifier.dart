import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';

/// `/humans`는 슈퍼/관리자 전용. 작업자는 [place-work-days] 행만으로 표시 이름을 만든다.
List<HumanModel> humanModelsFromPlaceWorkRows(List<PlaceWorkDayRead> rows) {
  final byHid = <int, PlaceWorkDayRead>{};
  for (final r in rows) {
    final prev = byHid[r.hid];
    if (prev == null) {
      byHid[r.hid] = r;
    } else if (prev.workrole.trim().isEmpty && r.workrole.trim().isNotEmpty) {
      byHid[r.hid] = r;
    }
  }
  final list = byHid.values
      .map((r) {
        final role = r.workrole.trim();
        final name = role.isNotEmpty ? role : '작업자 #${r.hid}';
        return HumanModel(
          hid: r.hid,
          hname: name,
          hnumber: '',
          hmemo: null,
          hdailyWage: r.dailywage,
          hdefaultRole: role,
          hstar: 0,
          hdelete: 0,
        );
      })
      .toList(growable: false);
  list.sort((a, b) => a.hname.compareTo(b.hname));
  return list;
}

/// [PlaceWorkforceScreen] 전용 — 인력 목록·투입 행·선택일.
class PlaceWorkforceState {
  const PlaceWorkforceState({
    required this.rows,
    required this.humans,
    required this.selectedDay,
    required this.initialLoading,
    required this.refreshing,
    this.loadError,
  });

  final List<PlaceWorkDayRead> rows;
  final List<HumanModel> humans;
  final DateTime selectedDay;

  /// 최초 진입 시에만 전체 로딩 UI와 함께 쓴다.
  final bool initialLoading;

  /// 재조회(저장 후 등) — 본문은 유지하고 상단 바 등만 표시.
  final bool refreshing;

  final Object? loadError;

  PlaceWorkforceState copyWith({
    List<PlaceWorkDayRead>? rows,
    List<HumanModel>? humans,
    DateTime? selectedDay,
    bool? initialLoading,
    bool? refreshing,
    Object? loadError,
    bool clearLoadError = false,
  }) {
    return PlaceWorkforceState(
      rows: rows ?? this.rows,
      humans: humans ?? this.humans,
      selectedDay: selectedDay ?? this.selectedDay,
      initialLoading: initialLoading ?? this.initialLoading,
      refreshing: refreshing ?? this.refreshing,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
    );
  }
}

final placeWorkforceProvider =
    NotifierProvider.family<PlaceWorkforceNotifier, PlaceWorkforceState, int>(
  PlaceWorkforceNotifier.new,
);

class PlaceWorkforceNotifier extends Notifier<PlaceWorkforceState> {
  PlaceWorkforceNotifier(this.pid);

  final int pid;

  @override
  PlaceWorkforceState build() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    Future.microtask(() => reload(silent: false));
    return PlaceWorkforceState(
      rows: const [],
      humans: const [],
      selectedDay: day,
      initialLoading: true,
      refreshing: false,
      loadError: null,
    );
  }

  void setSelectedDay(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    if (x == state.selectedDay) return;
    state = state.copyWith(selectedDay: x);
  }

  /// [silent]: 저장 직후 등 — 스켈레톤 없이 목록만 갱신.
  Future<void> reload({required bool silent}) async {
    final everLoaded = state.rows.isNotEmpty || state.humans.isNotEmpty;

    if (silent) {
      state = state.copyWith(
        refreshing: true,
        clearLoadError: true,
      );
    } else if (!everLoaded) {
      state = state.copyWith(
        initialLoading: true,
        refreshing: false,
        clearLoadError: true,
      );
    } else {
      state = state.copyWith(
        refreshing: true,
        initialLoading: false,
        clearLoadError: true,
      );
    }

    try {
      final allDays =
          await ref.read(superAdminRemoteUseCaseProvider).placeWorkDaysList();
      final forPlace =
          allDays.where((e) => e.pid == pid).toList(growable: false);
      forPlace.sort((a, b) => b.workdate.compareTo(a.workdate));

      final me = ref.read(authSessionProvider).asData?.value;
      final tryHumanDirectory = me?.isManagementRole ?? false;

      List<HumanModel> humans;
      if (tryHumanDirectory) {
        try {
          humans = await ref.read(humanUseCaseProvider).getAllWorkers();
        } catch (_) {
          humans = humanModelsFromPlaceWorkRows(forPlace);
        }
      } else {
        humans = humanModelsFromPlaceWorkRows(forPlace);
      }

      state = state.copyWith(
        rows: forPlace,
        humans: humans,
        initialLoading: false,
        refreshing: false,
        clearLoadError: true,
      );
    } catch (e, st) {
      debugPrint('PlaceWorkforceNotifier $e $st');
      state = state.copyWith(
        initialLoading: false,
        refreshing: false,
        loadError: e,
      );
    }
  }
}
