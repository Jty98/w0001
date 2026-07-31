import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_view_model.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_global_announcement_card.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_metric_chart_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_outstanding_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_schedule_section.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_kpi_section.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/management_dashboard_section_shell.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
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
  final ScrollController _scrollController = ScrollController();
  static const _scrollStorageKey =
      PageStorageKey<String>('management_dashboard_scroll');

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    final cs = Theme.of(context).colorScheme;
    final showBlockingLoad = ref.watch(
      dashboardProvider.select(
        (s) => s.isLoading && s.monthly.isEmpty && s.yearly.isEmpty,
      ),
    );
    final vm = ref.read(dashboardProvider.notifier);
    final padH = context.rsi(16);
    final gap = context.rsi(12);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('상황판'),
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () => context.push('/dashboard/profile'),
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ),
      body: AppRefreshIndicator(
        enabled: !showBlockingLoad,
        onRefresh: () async {
          await vm.fetch(silent: true);
          await ref.read(dashboardScheduleProvider.notifier).refresh();
          await _globalAnnouncementCardKey.currentState?.reloadPublic();
        },
        child: Skeletonizer(
          enabled: showBlockingLoad,
          child: CustomScrollView(
            key: _scrollStorageKey,
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padH, gap, padH, 0),
                  child: ManagementDashboardSectionShell(
                    icon: Icons.event_note_outlined,
                    title: '일정 · 메모',
                    denseHeader: true,
                    trailing: IconButton(
                      tooltip: '일정 추가',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.add,
                        size: context.rsi(22),
                        color: cs.onSurfaceVariant,
                      ),
                      onPressed: showBlockingLoad
                          ? null
                          : () {
                              final st = ref.read(dashboardScheduleProvider);
                              if (st.isWeekLoading) return;
                              openDashboardMemoEditor(
                                context,
                                ref,
                                existing: null,
                                initialDateOverride: st.selectedDay,
                              );
                            },
                    ),
                    child: const DashboardScheduleCompactBody(),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: gap)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padH),
                  child: ManagementDashboardSectionShell(
                    icon: Icons.campaign_outlined,
                    title: '작업자 전체 공지',
                    subtitle: '가입 작업자 전원에게 표시',
                    denseHeader: true,
                    trailing: IconButton(
                      tooltip: '새 공지',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.add_circle_outline,
                        size: context.rsi(20),
                        color: cs.onSurfaceVariant,
                      ),
                      onPressed: showBlockingLoad
                          ? null
                          : () => _globalAnnouncementCardKey.currentState
                              ?.openCreate(),
                    ),
                    child: DashboardGlobalAnnouncementCard(
                      key: _globalAnnouncementCardKey,
                      embedded: true,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: gap)),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padH, 0, padH, context.rsi(24)),
                sliver: SliverToBoxAdapter(
                  child: ManagementDashboardSectionShell(
                    icon: Icons.insights_outlined,
                    title: '경영 지표',
                    subtitle: '월별·연도별 현장 실적 요약',
                    child: DashboardKpiSection(
                      horizontalPadding: 0,
                      onMetricChart: _showMetricChart,
                      onOutstanding: _showOutstandingSheet,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
