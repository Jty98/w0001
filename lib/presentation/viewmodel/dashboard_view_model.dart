import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/dashboard_models.dart';
import 'package:w0001/data/model/monthly_summary_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show dbHelperProvider;

class DashboardState {
  final int selectedYear;
  final DashboardKpiSnapshot kpi;
  final List<MonthlySummaryModel> monthly;
  final List<YearlyDashboardPoint> yearly;
  final List<DashboardPlaceRow> places;
  final bool isLoading;

  const DashboardState({
    required this.selectedYear,
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
    DashboardKpiSnapshot? kpi,
    List<MonthlySummaryModel>? monthly,
    List<YearlyDashboardPoint>? yearly,
    List<DashboardPlaceRow>? places,
    bool? isLoading,
  }) {
    return DashboardState(
      selectedYear: selectedYear ?? this.selectedYear,
      kpi: kpi ?? this.kpi,
      monthly: monthly ?? this.monthly,
      yearly: yearly ?? this.yearly,
      places: places ?? this.places,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DashboardViewModel extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    Future.microtask(fetch);
    return DashboardState.initial();
  }

  Future<void> setYear(int year) async {
    state = state.copyWith(selectedYear: year);
    await fetch();
  }

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true);
    try {
      final db = ref.read(dbHelperProvider);
      final now = DateTime.now();
      final bundle = await db.loadDashboardDataBundle(
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

final dashboardProvider =
    NotifierProvider<DashboardViewModel, DashboardState>(DashboardViewModel.new);
