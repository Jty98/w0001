import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_view_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_metric_chart_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_outstanding_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_place_list_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_place_table.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_schedule_section.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_summary_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _showPlaceListSheet(BuildContext context, PlaceState filter) {
    showDashboardPlaceListSheet(context, filter: filter);
  }

  void _showOutstandingSheet(BuildContext context, WidgetRef ref) {
    final places = ref.read(dashboardProvider).places;
    showDashboardOutstandingSheet(context, places: places);
  }

  void _showMetricChart(
    BuildContext context,
    WidgetRef ref,
    DashboardMetricKind kind,
  ) {
    final state = ref.read(dashboardProvider);
    showDashboardMetricChartSheet(
      context,
      kind: kind,
      selectedYear: state.selectedYear,
      monthly: state.monthly,
      yearly: state.yearly,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final vm = ref.read(dashboardProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    final kpi = state.kpi;

    return Scaffold(
      appBar: AppBar(
        title: const Text('상황판'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: vm.fetch,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: state.isLoading
          ? null
          : FloatingActionButton(
              heroTag: 'dashboard_home_schedule_fab',
              tooltip: '일정 추가',
              onPressed: () {
                final st = ref.read(dashboardScheduleProvider);
                if (st.isWeekLoading) return;
                openDashboardMemoEditor(
                  context,
                  ref,
                  existing: null,
                  initialDateOverride: st.selectedDay,
                );
              },
              child: const Icon(Icons.add),
            ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await vm.fetch();
                await ref
                    .read(dashboardScheduleProvider.notifier)
                    .refresh();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: DashboardScheduleCompactCard(),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                          child: Text(
                            '${kpi.year}년 ${kpi.month}월 기준',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final w = (constraints.maxWidth - 8) / 2;
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  SizedBox(
                                    width: w,
                                    child: DashboardSummaryCard(
                                      title: '이번 달 공사금액',
                                      value: getPrice(price: kpi.monthlyContract),
                                      color: cs.tertiary,
                                      icon: Icons.description_outlined,
                                      onTap: () => _showMetricChart(
                                        context,
                                        ref,
                                        DashboardMetricKind.construction,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: w,
                                    child: DashboardSummaryCard(
                                      title: '이번 달 수금액',
                                      value:
                                          getPrice(price: kpi.monthlyCollection),
                                      color: Colors.teal[700]!,
                                      icon: Icons.account_balance_wallet_outlined,
                                      onTap: () => _showMetricChart(
                                        context,
                                        ref,
                                        DashboardMetricKind.collection,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: w,
                                    child: DashboardSummaryCard(
                                      title: '미수금 잔액',
                                      value: getPrice(
                                        price: kpi.outstandingReceivable,
                                      ),
                                      color: Colors.deepPurple[700]!,
                                      icon: Icons.request_quote_outlined,
                                      onTap: () => _showOutstandingSheet(
                                        context,
                                        ref,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: w,
                                    child: DashboardSummaryCard(
                                      title: '당월 완료 영업이익',
                                      value: getPrice(
                                        price: kpi.completedContractProfitTotal,
                                      ),
                                      valueSecondary:
                                          kpi.completedSitesInKpiMonth == 0
                                              ? '—'
                                              : '${kpi.completedContractMarginPct.toStringAsFixed(1)}%',
                                      color: cs.primary,
                                      icon: Icons.trending_up_rounded,
                                      onTap: () => _showMetricChart(
                                        context,
                                        ref,
                                        DashboardMetricKind.profitAndMargin,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: w,
                                    child: DashboardSummaryCard(
                                      title: '진행 중 현장',
                                      value: '${kpi.inProgressPlaces}',
                                      color: Colors.blueGrey[700]!,
                                      icon: Icons.construction_outlined,
                                      onTap: () => _showPlaceListSheet(
                                        context,
                                        PlaceState.incomplete,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: w,
                                    child: DashboardSummaryCard(
                                      title: '완료 현장',
                                      value: '${kpi.completedPlaces}',
                                      color: Colors.brown[700]!,
                                      icon: Icons.check_circle_outline,
                                      onTap: () => _showPlaceListSheet(
                                        context,
                                        PlaceState.complete,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: cs.outlineVariant.withValues(alpha: 0.55),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 0,
                                    ),
                                    child: Text(
                                      '현장별 요약',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DashboardPlaceTable(places: state.places),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: Text(
                            '「당월 완료 영업이익」은 이번 달 공사완료 처리된 건만 합산한 공사금액−현장원가입니다. 표의 이익·이익률은 현장별 공사금액 기준이며, 미수금은 공사금액 − 누적 수금입니다.',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 72),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
