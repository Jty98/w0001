import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/worker/worker_dashboard_remote_api.dart';
import 'package:w0001/data/model/worker_dashboard_models.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/util/worker_api_user_messages.dart';

final workerDashboardRemoteApiProvider = Provider<WorkerDashboardRemoteApi>(
  (ref) => WorkerDashboardRemoteApi(AppHttpClient.I),
);

@immutable
class WorkerDashboardQuery {
  const WorkerDashboardQuery({required this.year, this.month});

  /// `null` → 해당 [year] 전체 (서버 규약).
  final int year;
  final int? month;

  bool get isMonthly => month != null;
}

final workerDashboardQueryProvider =
    NotifierProvider<WorkerDashboardQueryNotifier, WorkerDashboardQuery>(
  WorkerDashboardQueryNotifier.new,
);

class WorkerDashboardQueryNotifier extends Notifier<WorkerDashboardQuery> {
  @override
  WorkerDashboardQuery build() {
    final n = DateTime.now();
    return WorkerDashboardQuery(year: n.year, month: n.month);
  }

  void setMonth(int year, int month) =>
      state = WorkerDashboardQuery(year: year, month: month);

  void setYearOnly(int year) => state = WorkerDashboardQuery(year: year);

  void setYearPreservingGranularity(int year) {
    state = WorkerDashboardQuery(year: year, month: state.month);
  }
}

/// 작업자 근로 현황 금액 표시 — 기본 세후(3.3% 공제).
final workerDashboardTaxStateProvider =
    NotifierProvider<WorkerDashboardTaxStateNotifier, TaxState>(
  WorkerDashboardTaxStateNotifier.new,
);

class WorkerDashboardTaxStateNotifier extends Notifier<TaxState> {
  @override
  TaxState build() => TaxState.taxOn;

  void setTaxState(TaxState? value) {
    if (value != null) state = value;
  }
}

extension WorkerDashboardTaxStateX on TaxState {
  bool get isTaxApply => this == TaxState.taxOn;
}

/// 작업자 「내 근로 현황」— `GET /worker/dashboard/summary`
class WorkerPersonalDashboardData {
  const WorkerPersonalDashboardData({
    required this.summary,
    required this.periodCaption,
    required this.chartLabels,
    required this.chartEntryCounts,
    required this.placeRollups,
    required this.placeRollupsPeriodLabel,
    required this.displayMonthTotals,
    required this.displayYearTotals,
    required this.skippedNonWorker,
  });

  final WorkerDashboardSummary summary;
  final String periodCaption;

  /// `1월` … `12월` — 선택 [WorkerDashboardQuery.year]의 근무일을 월 단위로 합산.
  /// 월 단위 필터 조회 중에도 연간 요약 API로 채워 별도로 집계됨.
  final List<String> chartLabels;
  final List<double> chartEntryCounts;

  /// 선택 기간(월/연)의 현장(pid)별 투입 금액.
  final List<WorkerDashboardPlaceRollup> placeRollups;
  final String placeRollupsPeriodLabel;

  final WorkerDashboardTotals? displayMonthTotals;
  final WorkerDashboardTotals? displayYearTotals;
  final bool skippedNonWorker;

  bool get missingHumanLink => !summary.humanLinked;

  List<WorkerDashboardWorkDay> get sortedWorkDays {
    final l = [...summary.workDays]
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return l;
  }

  bool get hasChartData => chartEntryCounts.any((e) => e > 0);
}

final workerPersonalDashboardProvider = AsyncNotifierProvider<
    WorkerPersonalDashboardNotifier, WorkerPersonalDashboardData>(
  WorkerPersonalDashboardNotifier.new,
);

final class WorkerDashboardLoadException implements Exception {
  const WorkerDashboardLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WorkerPersonalDashboardNotifier
    extends AsyncNotifier<WorkerPersonalDashboardData> {
  @override
  Future<WorkerPersonalDashboardData> build() async {
    final query = ref.watch(workerDashboardQueryProvider);
    final user = ref.watch(authSessionProvider).asData?.value;

    if (user == null || !user.isWorker) {
      return _emptySkipped(query);
    }

    try {
      final api = ref.read(workerDashboardRemoteApiProvider);
      final WorkerDashboardSummary summary;
      final WorkerDashboardSummary? yearSummary;
      final List<WorkerDashboardWorkDay> daysForMonthlyChart;

      if (query.isMonthly) {
        final pair = await Future.wait<WorkerDashboardSummary>([
          api.fetchSummary(year: query.year, month: query.month),
          api.fetchSummary(year: query.year),
        ]);
        summary = pair[0];
        yearSummary = pair[1];
        daysForMonthlyChart = _workDaysForChartYear(pair[1], query.year);
      } else {
        summary = await api.fetchSummary(year: query.year);
        yearSummary = null;
        daysForMonthlyChart = _workDaysForChartYear(summary, query.year);
      }

      final d =
          _deriveCharts(query, summary, chartWorkDays: daysForMonthlyChart);
      final placeRollups = _resolvePlaceRollups(
        query: query,
        monthSummary: summary,
        yearSummary: yearSummary ?? summary,
      );
      final placeRollupsPeriodLabel = query.isMonthly
          ? '${query.year}년 ${query.month}월 기준'
          : '${query.year}년 기준';
      return WorkerPersonalDashboardData(
        summary: summary,
        periodCaption: d.periodCaption,
        chartLabels: d.chartLabels,
        chartEntryCounts: d.chartEntryCounts,
        placeRollups: placeRollups,
        placeRollupsPeriodLabel: placeRollupsPeriodLabel,
        displayMonthTotals: d.displayMonthTotals,
        displayYearTotals: d.displayYearTotals,
        skippedNonWorker: false,
      );
    } on HttpClientException catch (e) {
      final friendly = workerDashboardFriendlyMessageKo(e);
      throw WorkerDashboardLoadException(friendly ?? e.message);
    }
  }

  WorkerPersonalDashboardData _emptySkipped(WorkerDashboardQuery query) {
    final summary = WorkerDashboardSummary(
      hid: null,
      workerDisplayName: '',
      year: query.year,
      month: query.month,
      workDays: const [],
      monthTotals: null,
      yearTotals: null,
    );
    final d = _deriveCharts(query, summary, chartWorkDays: const []);
    return WorkerPersonalDashboardData(
      summary: summary,
      periodCaption: d.periodCaption,
      chartLabels: d.chartLabels,
      chartEntryCounts: d.chartEntryCounts,
      placeRollups: const [],
      placeRollupsPeriodLabel: query.isMonthly
          ? '${query.year}년 ${query.month}월 기준'
          : '${query.year}년 기준',
      displayMonthTotals: d.displayMonthTotals,
      displayYearTotals: d.displayYearTotals,
      skippedNonWorker: true,
    );
  }

  Future<void> reload({bool silent = false}) async {
    if (!silent && state.asData?.value == null) {
      state = const AsyncLoading();
    }
    state = await AsyncValue.guard(() async => build());
  }
}

({
  String periodCaption,
  List<String> chartLabels,
  List<double> chartEntryCounts,
  WorkerDashboardTotals? displayMonthTotals,
  WorkerDashboardTotals? displayYearTotals,
}) _deriveCharts(
  WorkerDashboardQuery query,
  WorkerDashboardSummary s, {
  required List<WorkerDashboardWorkDay> chartWorkDays,
}) {
  final periodCaption =
      query.isMonthly ? '${query.year}년 ${query.month}월' : '${query.year}년 전체';

  WorkerDashboardTotals? monthTotals = s.monthTotals;
  WorkerDashboardTotals? yearTotals = s.yearTotals;

  if (monthTotals == null && query.isMonthly && s.workDays.isNotEmpty) {
    monthTotals = workerDashboardTotalsFromWorkDays(s.workDays);
  }

  if (yearTotals == null && !query.isMonthly && s.workDays.isNotEmpty) {
    yearTotals = workerDashboardTotalsFromWorkDays(s.workDays);
  }

  final chartLabels = List.generate(12, (i) => '${i + 1}월');
  final counts = List<double>.filled(12, 0);
  final seenDay = <String>{};
  for (final w in chartWorkDays) {
    final k = w.dateKey;
    if (k.isEmpty || !seenDay.add(k)) continue;
    final mo = _monthOfIso(k);
    if (mo == null || mo < 1 || mo > 12) continue;
    counts[mo - 1] += 1;
  }

  final displayMonth = query.isMonthly ? monthTotals : null;
  final displayYear =
      query.isMonthly ? yearTotals : (yearTotals ?? monthTotals);

  return (
    periodCaption: periodCaption,
    chartLabels: chartLabels,
    chartEntryCounts: counts,
    displayMonthTotals: displayMonth,
    displayYearTotals: displayYear,
  );
}

List<WorkerDashboardPlaceRollup> _resolvePlaceRollups({
  required WorkerDashboardQuery query,
  required WorkerDashboardSummary monthSummary,
  required WorkerDashboardSummary yearSummary,
}) {
  if (monthSummary.placeRollups.isNotEmpty) {
    return monthSummary.placeRollups;
  }
  if (query.isMonthly) {
    final fromMonth = workerDashboardPlaceRollupsFromWorkDays(
      monthSummary.workDays,
    );
    if (fromMonth.isNotEmpty) return fromMonth;
  }
  if (yearSummary.placeRollups.isNotEmpty) {
    return yearSummary.placeRollups;
  }
  final days = query.isMonthly
      ? monthSummary.workDays
      : _workDaysForChartYear(yearSummary, query.year);
  return workerDashboardPlaceRollupsFromWorkDays(days);
}

/// 월별 차트용: [summary]의 `work_days` 중 [year] 연도인 행만 (날짜 키 기준).
List<WorkerDashboardWorkDay> _workDaysForChartYear(
  WorkerDashboardSummary summary,
  int year,
) {
  final out = <WorkerDashboardWorkDay>[];
  for (final w in summary.workDays) {
    final y = _yearOfIso(w.dateKey);
    if (y == year) out.add(w);
  }
  return out;
}

int? _yearOfIso(String key) {
  final t = key.trim();
  if (t.length >= 4 && int.tryParse(t.substring(0, 4)) != null) {
    return int.parse(t.substring(0, 4));
  }
  final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})');
  final m1 = slash.firstMatch(t);
  if (m1 != null) return int.tryParse(m1.group(3)!);
  final dot = RegExp(r'^(\d{4})\.(\d{1,2})\.(\d{1,2})');
  final m2 = dot.firstMatch(t);
  if (m2 != null) return int.tryParse(m2.group(1)!);
  return null;
}

int? _monthOfIso(String key) {
  final t = key.trim();
  if (t.length >= 7) {
    final mo = int.tryParse(t.substring(5, 7));
    if (mo != null && mo >= 1 && mo <= 12) return mo;
  }
  final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})');
  final m1 = slash.firstMatch(t);
  if (m1 != null) return int.tryParse(m1.group(1)!);
  final dot = RegExp(r'^(\d{4})\.(\d{1,2})\.(\d{1,2})');
  final m2 = dot.firstMatch(t);
  if (m2 != null) return int.tryParse(m2.group(2)!);
  return null;
}
