import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/util/funtions.dart';

const int kWorkInstructionOverviewPrefetchDays = 45;

class WorkInstructionOverviewState {
  const WorkInstructionOverviewState({
    required this.rows,
    required this.initialLoading,
    required this.refreshing,
    this.loadedFrom,
    this.loadedTo,
  });

  final List<PlaceWorkDayRead> rows;
  final bool initialLoading;
  final bool refreshing;
  final DateTime? loadedFrom;
  final DateTime? loadedTo;

  factory WorkInstructionOverviewState.initial() =>
      const WorkInstructionOverviewState(
        rows: [],
        initialLoading: true,
        refreshing: false,
      );

  bool get hasCache => rows.isNotEmpty;

  bool covers(DateTime from, DateTime toExclusive) {
    final loadedFrom = this.loadedFrom;
    final loadedTo = this.loadedTo;
    if (loadedFrom == null || loadedTo == null) return false;
    return !from.isBefore(loadedFrom) && !toExclusive.isAfter(loadedTo);
  }

  WorkInstructionOverviewState copyWith({
    List<PlaceWorkDayRead>? rows,
    bool? initialLoading,
    bool? refreshing,
    DateTime? loadedFrom,
    DateTime? loadedTo,
  }) {
    return WorkInstructionOverviewState(
      rows: rows ?? this.rows,
      initialLoading: initialLoading ?? this.initialLoading,
      refreshing: refreshing ?? this.refreshing,
      loadedFrom: loadedFrom ?? this.loadedFrom,
      loadedTo: loadedTo ?? this.loadedTo,
    );
  }
}

final workInstructionOverviewProvider = NotifierProvider<
    WorkInstructionOverviewNotifier, WorkInstructionOverviewState>(
  WorkInstructionOverviewNotifier.new,
);

/// 작업지시 탭 일자별 투입 내역 — 탭 전환·뒤로가기에도 유지.
class WorkInstructionOverviewNotifier
    extends Notifier<WorkInstructionOverviewState> {
  @override
  WorkInstructionOverviewState build() {
    ref.listen<AsyncValue<UserRead?>>(
      authSessionProvider,
      (prev, next) {
        final user = next.asData?.value;
        if (user == null || user.isWorker) {
          state = WorkInstructionOverviewState.initial();
          return;
        }
        final prevUid = prev?.asData?.value?.uid;
        if (prevUid == user.uid && state.loadedFrom != null) return;
        Future.microtask(() => ensureRange(DateTime.now()));
      },
      fireImmediately: true,
    );
    return WorkInstructionOverviewState.initial();
  }

  DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void>? _inflight;

  List<PlaceWorkDayRead> _merge(
    List<PlaceWorkDayRead> current,
    List<PlaceWorkDayRead> incoming,
  ) {
    final map = <int, PlaceWorkDayRead>{
      for (final r in current)
        if (r.pwdid > 0) r.pwdid: r,
    };
    for (final r in incoming) {
      if (r.pwdid > 0) map[r.pwdid] = r;
    }
    return map.values.toList(growable: false);
  }

  /// [force]면 구간을 다시 조회. 캐시가 있으면 스피너 없이 갱신.
  Future<void> ensureRange(DateTime center, {bool force = false}) async {
    final user = ref.read(authSessionProvider).asData?.value;
    if (user == null || user.isWorker) return;

    final day = _ymd(center);
    final from = day
        .subtract(const Duration(days: kWorkInstructionOverviewPrefetchDays));
    final toExclusive =
        day.add(const Duration(days: kWorkInstructionOverviewPrefetchDays + 1));
    if (!force && state.covers(from, toExclusive)) return;

    if (_inflight != null && !force) {
      await _inflight;
      if (state.covers(from, toExclusive)) return;
    }

    final hasCache = state.hasCache;
    state = state.copyWith(
      initialLoading: !hasCache,
      refreshing: hasCache,
    );
    final future = _fetchRange(
      from: from,
      toExclusive: toExclusive,
      replace: force,
    );
    _inflight = future;
    try {
      await future;
    } finally {
      if (identical(_inflight, future)) _inflight = null;
    }
  }

  Future<void> _fetchRange({
    required DateTime from,
    required DateTime toExclusive,
    required bool replace,
  }) async {
    try {
      final uc = ref.read(superAdminRemoteUseCaseProvider);
      var rows = await uc.placeWorkDaysQuery(
        ListQuery(
          from: formatDateTimeToIsoDate(from),
          to: formatDateTimeToIsoDate(toExclusive),
          limit: 1000,
        ),
      );
      if (rows.isEmpty) {
        try {
          rows = await uc.placeWorkDaysList();
        } catch (_) {}
      }
      if (!ref.mounted) return;
      state = state.copyWith(
        rows: replace
            ? List<PlaceWorkDayRead>.of(rows)
            : _merge(state.rows, rows),
        loadedFrom: state.loadedFrom == null || from.isBefore(state.loadedFrom!)
            ? from
            : state.loadedFrom,
        loadedTo: state.loadedTo == null || toExclusive.isAfter(state.loadedTo!)
            ? toExclusive
            : state.loadedTo,
        initialLoading: false,
        refreshing: false,
      );
    } catch (_) {
      try {
        final rows =
            await ref.read(superAdminRemoteUseCaseProvider).placeWorkDaysList();
        if (!ref.mounted) return;
        state = state.copyWith(
          rows: rows,
          loadedFrom: DateTime(2000),
          loadedTo: DateTime(2100),
          initialLoading: false,
          refreshing: false,
        );
      } catch (_) {
        if (!ref.mounted) return;
        state = state.copyWith(initialLoading: false, refreshing: false);
      }
    }
  }

  Future<void> reload({DateTime? around}) =>
      ensureRange(around ?? DateTime.now(), force: true);
}
