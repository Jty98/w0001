import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_view_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_global_announcement_card.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_metric_chart_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_outstanding_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_schedule_section.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_summary_card.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 관리자·슈퍼관리자 전용 **상황판** (`/dashboard` — 작업자는 [DashboardScreen]에서 분기되어 오지 않음).
class ManagementDashboardScreen extends ConsumerStatefulWidget {
  const ManagementDashboardScreen({super.key});

  @override
  ConsumerState<ManagementDashboardScreen> createState() =>
      _ManagementDashboardScreenState();
}

class _ManagementDashboardScreenState
    extends ConsumerState<ManagementDashboardScreen> {
  final GlobalKey<DashboardGlobalAnnouncementCardState>
      _globalAnnouncementCardKey =
      GlobalKey<DashboardGlobalAnnouncementCardState>();

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
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('상황판'),
        actions: [
          IconButton(
              onPressed: () {
                context.push('/dashboard/profile');
              },
              icon: const Icon(Icons.person)),
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
      body: RefreshIndicator(
              onRefresh: () async {
                await vm.fetch();
                await ref.read(dashboardScheduleProvider.notifier).refresh();
                await _globalAnnouncementCardKey.currentState?.reloadPublic();
              },
              child: Skeletonizer(
                enabled: state.isLoading,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.rsi(12),
                        context.rsi(8),
                        context.rsi(12),
                        0,
                      ),
                      child: const DashboardScheduleCompactCard(),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: context.rsi(14))),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.rsi(12),
                        0,
                        context.rsi(12),
                        context.rsi(14),
                      ),
                      child: DashboardGlobalAnnouncementCard(
                        key: _globalAnnouncementCardKey,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(0, 0, 0, context.rsi(28)),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            context.rsi(12),
                            0,
                            context.rsi(12),
                            context.rsi(4),
                          ),
                          child: Text(
                            '${kpi.year}년 ${kpi.month}월 기준',
                            style: tt.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: context.rsi(12)),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final gap = context.rsi(8);
                              final w = (constraints.maxWidth - gap) / 2;
                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
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
                                      color: cs.tertiaryContainer,
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
                                      color: cs.primary,
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
                                      color: cs.secondary,
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
                                      color: cs.onSurfaceVariant,
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
      ),
    );
  }
}
