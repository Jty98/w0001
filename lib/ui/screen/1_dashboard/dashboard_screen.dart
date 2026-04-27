import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_view_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_metric_chart_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_outstanding_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_schedule_section.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_summary_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSessionIfNeeded());
  }

  /// 토큰만 있고 [authSessionProvider]가 비어 있을 때(앱 재실행·자동 로그인 등) GET `/auth/me`로 채움
  void _loadSessionIfNeeded() {
    if (!mounted) return;
    final s = ref.read(authSessionProvider);
    if (s.isLoading) return;
    if (s.maybeWhen(data: (u) => u != null, orElse: () => false)) return;
    ref.read(authSessionProvider.notifier).loadCurrentUser();
  }

  void _showOutstandingSheet(BuildContext context, WidgetRef ref) {
    final places = ref.read(dashboardProvider).places;
    showDashboardOutstandingSheet(context, places: places);
  }

  void _showMetricChart(
    BuildContext context,
    WidgetRef ref,
    DashboardMetricKind kind,
    DashboardPlaceBreakdownFilter placeFilter,
  ) {
    final state = ref.read(dashboardProvider);
    showDashboardMetricChartSheet(
      context,
      kind: kind,
      selectedYear: state.selectedYear,
      monthly: state.monthly,
      yearly: state.yearly,
      places: state.places,
      initialPlaceFilter: placeFilter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final vm = ref.read(dashboardProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    final kpi = state.kpi;

    return Scaffold(
      appBar: AppBar(
        title: const Text('상황판'),
        actions: [
          IconButton(onPressed: () {
            context.push('/dashboard/profile');
          }, icon: const Icon(Icons.person)),
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
              child: const Icon(Icons.edit_note_rounded),
            ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await vm.fetch();
                await ref.read(dashboardScheduleProvider.notifier).refresh();
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
                                      title: '공사금액',
                                      value:
                                          getPrice(price: kpi.monthlyContract),
                                      color: cs.tertiary,
                                      icon: Icons.description_outlined,
                                      onTap: () => _showMetricChart(
                                        context,
                                        ref,
                                        DashboardMetricKind.construction,
                                        DashboardPlaceBreakdownFilter.all,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: w,
                                    child: DashboardSummaryCard(
                                      title: '공사원가',
                                      value: getPrice(price: kpi.monthlyCost),
                                      color: Colors.orange[700]!,
                                      icon: Icons.payments_outlined,
                                      onTap: () => _showMetricChart(
                                        context,
                                        ref,
                                        DashboardMetricKind.cost,
                                        DashboardPlaceBreakdownFilter.all,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: w,
                                    child: DashboardSummaryCard(
                                      title: '수금액',
                                      value: getPrice(
                                          price: kpi.monthlyCollection),
                                      color: Colors.teal[700]!,
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                      onTap: () => _showMetricChart(
                                        context,
                                        ref,
                                        DashboardMetricKind.collection,
                                        DashboardPlaceBreakdownFilter.all,
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
                                      title: '영업이익',
                                      value: getPrice(
                                        price: kpi.completedContractProfitTotal,
                                      ),
                                      valueSecondary: kpi
                                                  .completedSitesInKpiMonth ==
                                              0
                                          ? '—'
                                          : '${kpi.completedContractMarginPct.toStringAsFixed(1)}%',
                                      color: cs.primary,
                                      icon: Icons.trending_up_rounded,
                                      onTap: () => _showMetricChart(
                                        context,
                                        ref,
                                        DashboardMetricKind.profitAndMargin,
                                        DashboardPlaceBreakdownFilter.all,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: w,
                                    child: DashboardSummaryCard(
                                      title: '현장 현황',
                                      subtitle: '진행중 · 완료',
                                      value: '${kpi.inProgressPlaces}곳',
                                      valueSecondary: '${kpi.completedPlaces}곳',
                                      color: Colors.blueGrey[700]!,
                                      icon: Icons.construction_outlined,
                                      onTap: () => _showMetricChart(
                                        context,
                                        ref,
                                        DashboardMetricKind.siteCounts,
                                        DashboardPlaceBreakdownFilter.all,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
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
