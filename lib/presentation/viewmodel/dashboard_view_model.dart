import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/dashboard_models.dart';
import 'package:w0001/data/model/monthly_summary_model.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_remote_providers.dart';

enum DashboardKpiPeriodMode { monthly, yearly }

class DashboardState {
  final int selectedYear;
  final DashboardKpiPeriodMode kpiPeriodMode;
  final int kpiSelectedMonth;
  final DashboardKpiSnapshot kpi;
  final List<MonthlySummaryModel> monthly;
  final List<YearlyDashboardPoint> yearly;
  final List<DashboardPlaceRow> places;
  final bool isLoading;

  const DashboardState({
    required this.selectedYear,
    required this.kpiPeriodMode,
    required this.kpiSelectedMonth,
    required this.kpi,
    required this.monthly,
    required this.yearly,
    required this.places,
    required this.isLoading,
  });

  factory DashboardState.initial() {
    final now = DateTime.now();
    return DashboardState(
      selectedYear: now.year,
      kpiPeriodMode: DashboardKpiPeriodMode.monthly,
      kpiSelectedMonth: now.month,
      kpi: DashboardKpiSnapshot(
        year: now.year,
        month: now.month,
        monthlyContract: 0,
        monthlyCollection: 0,
        monthlyCost: 0,
        inProgressPlaces: 0,
        completedPlaces: 0,
        outstandingReceivable: 0,
        completedSitesInKpiMonth: 0,
        completedContractMarginPct: 0,
        completedContractProfitTotal: 0,
      ),
      monthly: const [],
      yearly: const [],
      places: const [],
      isLoading: false,
    );
  }

  DashboardState copyWith({
    int? selectedYear,
    DashboardKpiPeriodMode? kpiPeriodMode,
    int? kpiSelectedMonth,
    DashboardKpiSnapshot? kpi,
    List<MonthlySummaryModel>? monthly,
    List<YearlyDashboardPoint>? yearly,
    List<DashboardPlaceRow>? places,
    bool? isLoading,
  }) {
    return DashboardState(
      selectedYear: selectedYear ?? this.selectedYear,
      kpiPeriodMode: kpiPeriodMode ?? this.kpiPeriodMode,
      kpiSelectedMonth: kpiSelectedMonth ?? this.kpiSelectedMonth,
      kpi: kpi ?? this.kpi,
      monthly: monthly ?? this.monthly,
      yearly: yearly ?? this.yearly,
      places: places ?? this.places,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DashboardViewModel extends Notifier<DashboardState> {
  Future<void>? _fetchInFlight;

  bool? _tryReadUserIsWorker() {
    try {
      return ref.read(authSessionProvider).asData?.value?.isWorker;
    } catch (e) {
      if (e is StateError && e.toString().contains('uninitialized provider')) {
        return null;
      }
      rethrow;
    }
  }

  void _onAuthSessionForDashboard(
      AsyncValue<UserRead?>? prev, AsyncValue<UserRead?> next) {
    final u = next.asData?.value;
    if (u == null) return;
    if (u.isWorker) {
      state = DashboardState.initial();
      return;
    }
    final prevUser = prev?.asData?.value;
    if (prevUser != null && prevUser.uid == u.uid && prevUser.role == u.role) {
      return;
    }
    unawaited(
        Future<void>.microtask(() => fetch(isWorker: false, force: true)));
  }

  @override
  DashboardState build() {
    ref.listen<AsyncValue<UserRead?>>(
        authSessionProvider, _onAuthSessionForDashboard,
        fireImmediately: true);
    return DashboardState.initial();
  }

  bool get _hasLoadedData =>
      state.monthly.isNotEmpty || state.yearly.isNotEmpty;

  void setKpiPeriodMode(DashboardKpiPeriodMode mode) {
    if (state.kpiPeriodMode == mode) return;
    state = state.copyWith(kpiPeriodMode: mode);
  }

  void setKpiSelectedMonth(int month) {
    final clamped = month.clamp(1, 12);
    if (state.kpiSelectedMonth == clamped) return;
    state = state.copyWith(kpiSelectedMonth: clamped);
  }

  Future<void> setYear(int year) async {
    final isWorker = _tryReadUserIsWorker() ?? false;
    if (isWorker) {
      if (state.selectedYear == year) return;
      state = state.copyWith(selectedYear: year);
      return;
    }
    if (state.selectedYear == year) return;

    state = state.copyWith(selectedYear: year);

    final hasYearlyPoint = state.yearly.any((y) => y.year == year);
    final needsFetch = state.kpiPeriodMode == DashboardKpiPeriodMode.monthly ||
        !hasYearlyPoint;
    if (needsFetch) {
      await fetch(isWorker: isWorker, silent: true);
    }
  }

  /// 상황판 KPI·차트 데이터. [force]면 진행 중 요청을 무시하고 새로 조회한다.
  /// [silent]면 기존 데이터를 유지한 채 백그라운드 갱신(스크롤·스켈레톤 유지).
  Future<void> fetch({
    bool force = false,
    bool? isWorker,
    bool silent = false,
  }) async {
    if (force) {
      _fetchInFlight = null;
    }
    if (_fetchInFlight != null) {
      return _fetchInFlight;
    }
    _fetchInFlight = _fetchBody(isWorker: isWorker, silent: silent);
    try {
      await _fetchInFlight;
    } finally {
      _fetchInFlight = null;
    }
  }

  Future<void> _fetchBody({bool? isWorker, bool silent = false}) async {
    final worker = isWorker ?? _tryReadUserIsWorker();
    if (worker == true) {
      state = state.copyWith(isLoading: false);
      return;
    }
    if (worker == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    final showBlockingLoader = !silent || !_hasLoadedData;
    if (showBlockingLoader) {
      state = state.copyWith(isLoading: true);
    }
    try {
      final now = DateTime.now();
      final bundle = await ref.read(dashboardRemoteUseCaseProvider).loadBundle(
            selectedYear: state.selectedYear,
            kpiYear: now.year,
            kpiMonth: now.month,
          );
      state = state.copyWith(
        kpi: bundle.kpi,
        monthly: bundle.monthly,
        yearly: bundle.yearly,
        places: bundle.places,
      );
    } catch (e, st) {
      debugPrint('Dashboard fetch failed: $e\n$st');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final dashboardProvider = NotifierProvider<DashboardViewModel, DashboardState>(
    DashboardViewModel.new);
