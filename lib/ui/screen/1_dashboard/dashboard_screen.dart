import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_view_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_metric_chart_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_outstanding_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_schedule_section.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_global_announcement_card.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_summary_card.dart';
import 'package:w0001/presentation/viewmodel/user_notifications_providers.dart';
import 'package:w0001/ui/widget/notification_bell_button.dart';
import 'package:w0001/util/responsive_layout.dart';

// 프로필 버튼 제거 - 설정 탭으로 이동

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final GlobalKey<DashboardGlobalAnnouncementCardState> _globalAnnouncementCardKey =
      GlobalKey<DashboardGlobalAnnouncementCardState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSessionIfNeeded();
      _ensureDashboardDataLoaded(force: true);
      ref.invalidate(userNotificationInboxProvider);
    });
  }

  /// 공지 카드처럼 화면 진입 시 KPI·일정을 직접 불러온다 (provider auth 리스너만으로는 누락될 수 있음).
  void _ensureDashboardDataLoaded({bool force = false}) {
    if (!mounted) return;
    final u = ref.read(authSessionProvider).asData?.value;
    if (u == null || u.isWorker) return;
    unawaited(ref.read(dashboardProvider.notifier).fetch(
      force: force,
      isWorker: u.isWorker,
    ));
    unawaited(
      ref.read(dashboardScheduleProvider.notifier).ensureWeekLoaded(force: force),
    );
  }

  /// 토큰만 있고 [authSessionProvider]가 비어 있을 때(앱 재실행·자동 로그인 등) GET `/auth/me`로 채움
  void _loadSessionIfNeeded() {
    if (!mounted) return;
    final s = ref.read(authSessionProvider);
    if (s.maybeWhen(data: (u) => u != null, orElse: () => false)) return;
    if (s.isLoading) return;
    unawaited(
      ref.read(authSessionProvider.notifier).loadCurrentUser(awaitWarmUp: true),
    );
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
    ref.listen<AsyncValue<UserRead?>>(authSessionProvider, (prev, next) {
      final u = next.asData?.value;
      if (u == null || u.isWorker) return;
      if (prev?.asData?.value?.uid == u.uid) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureDashboardDataLoaded(force: true);
      });
    });

    final state = ref.watch(dashboardProvider);
    final vm = ref.read(dashboardProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    final kpi = state.kpi;
    final tt = Theme.of(context).textTheme;
    final padH = context.rs(12);
    final gridGap = context.rs(8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('상황판'),
        actions: const [
          NotificationBellButton(),
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
                      padding: EdgeInsets.fromLTRB(padH, context.rs(8), padH, 0),
                      child: const DashboardScheduleCompactCard(),
                    ),
                  ),
                  SliverToBoxAdapter(child: rsV(context, 14)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padH, 0, padH, context.rs(14)),
                      child: DashboardGlobalAnnouncementCard(
                        key: _globalAnnouncementCardKey,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(0, 0, 0, context.rs(28)),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Padding(
                          padding: EdgeInsets.fromLTRB(padH, 0, padH, context.rs(4)),
                          child: Text(
                            '${kpi.year}년 ${kpi.month}월 기준',
                            style: tt.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: padH),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final w = (constraints.maxWidth - gridGap) / 2;
                              return Wrap(
                                spacing: gridGap,
                                runSpacing: gridGap,
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
                        rsV(context, 72),
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
