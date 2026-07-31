import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/domain/dashboard_customization.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_layout_customization_provider.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/daily_quote_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_view_model.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/daily_quote_dashboard_section.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_metric_chart_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_outstanding_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_schedule_section.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_global_announcement_card.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_kpi_section.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/management_dashboard_section_shell.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_section_preview_tile.dart';
import 'package:w0001/presentation/viewmodel/user_notifications_providers.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/notification_bell_button.dart';
import 'package:w0001/util/responsive_layout.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final GlobalKey<DashboardGlobalAnnouncementCardState>
      _globalAnnouncementCardKey =
      GlobalKey<DashboardGlobalAnnouncementCardState>();
  final ScrollController _scrollController = ScrollController();
  static const _scrollStorageKey =
      PageStorageKey<String>('dashboard_home_scroll');
  final Set<String> _removingSectionIds = <String>{};

  Set<String> _visibleManagementSectionIds() {
    final layout = ref.read(managementDashboardLayoutCustomizationProvider);
    if (!layout.isReady) return const <String>{};
    return layout.visibleEntries.map((e) => e.sectionId).toSet();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSessionIfNeeded();
      unawaited(() async {
        await ref
            .read(managementDashboardLayoutCustomizationProvider.notifier)
            .load();
        if (mounted) _ensureDashboardDataLoaded(force: true);
      }());
      ref.invalidate(userNotificationInboxProvider);
    });
  }

  void _ensureDashboardDataLoaded({bool force = false}) {
    if (!mounted) return;
    final u = ref.read(authSessionProvider).asData?.value;
    if (u == null || u.isWorker) return;
    final visible = _visibleManagementSectionIds();
    if (visible.isEmpty) return;
    if (visible.contains(DashboardSectionIds.managementKpi)) {
      unawaited(ref.read(dashboardProvider.notifier).fetch(
            force: force,
            isWorker: u.isWorker,
          ));
    }
    if (visible.contains(DashboardSectionIds.managementSchedule)) {
      unawaited(
        ref
            .read(dashboardScheduleProvider.notifier)
            .ensureWeekLoaded(force: force),
      );
    }
  }

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

  List<DashboardSectionDefinition> _hiddenSectionsFor(
    DashboardLayoutCustomizationState state,
  ) {
    final hiddenIds = state.entries
        .where((entry) => !entry.visible)
        .map((entry) => entry.sectionId)
        .toSet();
    return DashboardCustomizationRegistry.sectionsForRole(
      DashboardLayoutRoleScope.management,
    )
        .where((section) => hiddenIds.contains(section.id))
        .toList(growable: false);
  }

  Future<void> _showAddSectionSheet(
    BuildContext context,
    DashboardLayoutCustomizationState layoutState,
  ) async {
    final notifier =
        ref.read(managementDashboardLayoutCustomizationProvider.notifier);
    final sections = _hiddenSectionsFor(layoutState);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        if (sections.isEmpty) {
          return SizedBox(
            height: context.rsi(180),
            child: Center(
              child: Text(
                '추가할 수 있는 섹션이 없습니다.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          );
        }
        final width = MediaQuery.sizeOf(context).width;
        final columns = width >= 720 ? 3 : 2;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            context.rsi(16),
            context.rsi(8),
            context.rsi(16),
            context.rsi(24),
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: context.rsi(10),
            mainAxisSpacing: context.rsi(10),
            childAspectRatio: 1.12,
          ),
          itemCount: sections.length,
          itemBuilder: (context, index) {
            final section = sections[index];
            return DashboardSectionPreviewTile(
              title: section.title,
              icon: section.icon,
              previewKind: _previewKindForSection(section.id),
              onTap: () {
                unawaited(notifier.restoreSection(section.id));
                Navigator.of(context).pop();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSectionById({
    required String sectionId,
    required BuildContext context,
    required bool showBlockingLoad,
    required ColorScheme cs,
    required double padH,
  }) {
    switch (sectionId) {
      case DashboardSectionIds.managementDailyQuote:
        return Padding(
          padding: EdgeInsets.fromLTRB(padH, context.rsi(6), padH, 0),
          child: CollapsibleDailyQuoteCard(
            onOpenSettings: () =>
                context.push('/dashboard/extras/daily-quotes'),
          ),
        );
      case DashboardSectionIds.managementSchedule:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: padH),
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
        );
      case DashboardSectionIds.managementAnnouncement:
        return Padding(
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
                  : () => _globalAnnouncementCardKey.currentState?.openCreate(),
            ),
            child: DashboardGlobalAnnouncementCard(
              key: _globalAnnouncementCardKey,
              embedded: true,
            ),
          ),
        );
      case DashboardSectionIds.managementKpi:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: padH),
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
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _editSubtitleForSection(String sectionId) {
    switch (sectionId) {
      case DashboardSectionIds.managementDailyQuote:
        return '오늘 문구 미리보기 카드';
      case DashboardSectionIds.managementSchedule:
        return '일정/메모 요약';
      case DashboardSectionIds.managementAnnouncement:
        return '작업자 공지 요약';
      case DashboardSectionIds.managementKpi:
        return '월별 지표 요약';
      default:
        return '';
    }
  }

  DashboardSectionPreviewKind _previewKindForSection(String sectionId) {
    switch (sectionId) {
      case DashboardSectionIds.managementDailyQuote:
        return DashboardSectionPreviewKind.quote;
      case DashboardSectionIds.managementSchedule:
        return DashboardSectionPreviewKind.schedule;
      case DashboardSectionIds.managementAnnouncement:
        return DashboardSectionPreviewKind.announcement;
      case DashboardSectionIds.managementKpi:
        return DashboardSectionPreviewKind.kpi;
      default:
        return DashboardSectionPreviewKind.generic;
    }
  }

  Widget _buildEditCompactCard(
    BuildContext context, {
    required String sectionId,
    required String title,
    required String subtitle,
    required int index,
    required bool canRemove,
    required bool requiredSection,
  }) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.symmetric(horizontal: context.rsi(14)),
      constraints: BoxConstraints(minHeight: context.rsi(92)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(10),
          context.rsi(8),
          context.rsi(10),
          context.rsi(8),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Container(
                width: context.rsi(36),
                height: context.rsi(36),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(width: context.rsi(10)),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  SizedBox(height: context.rsi(4)),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  SizedBox(height: context.rsi(8)),
                  Row(
                    children: [
                      Expanded(child: _compactLine(context, 0.82)),
                      SizedBox(width: context.rsi(8)),
                      Expanded(child: _compactLine(context, 0.55)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: context.rsi(6)),
            if (requiredSection)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rsi(8),
                  vertical: context.rsi(4),
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '필수',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            IconButton(
              tooltip: requiredSection ? '필수 섹션' : '섹션 삭제',
              onPressed: canRemove
                  ? () {
                      unawaited(
                          _removeWithAnimation(context, sectionId, title));
                    }
                  : null,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactLine(BuildContext context, double widthFactor) {
    final cs = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: context.rsi(6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Future<void> _removeWithAnimation(
    BuildContext context,
    String sectionId,
    String title,
  ) async {
    if (_removingSectionIds.contains(sectionId)) return;
    setState(() {
      _removingSectionIds.add(sectionId);
    });
    await Future<void>.delayed(const Duration(milliseconds: 170));
    final notifier =
        ref.read(managementDashboardLayoutCustomizationProvider.notifier);
    final ok = notifier.removeSection(sectionId);
    if (mounted) {
      setState(() {
        _removingSectionIds.remove(sectionId);
      });
    }
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$title" 섹션을 삭제했습니다.'),
        action: SnackBarAction(
          label: '실행 취소',
          onPressed: () {
            unawaited(notifier.restoreSection(sectionId));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserRead?>>(authSessionProvider, (prev, next) {
      final u = next.asData?.value;
      if (u == null || u.isWorker) return;
      final prevUser = prev?.asData?.value;
      if (prevUser != null &&
          prevUser.uid == u.uid &&
          prevUser.role == u.role) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureDashboardDataLoaded(force: true);
      });
    });
    ref.listen<DashboardLayoutCustomizationState>(
      managementDashboardLayoutCustomizationProvider,
      (prev, next) {
        if (!next.isReady) return;
        final prevVisible = prev == null
            ? const <String>{}
            : prev.visibleEntries.map((e) => e.sectionId).toSet();
        final nextVisible = next.visibleEntries.map((e) => e.sectionId).toSet();
        final hasNewVisible = nextVisible.difference(prevVisible).isNotEmpty;
        if ((prev == null || !prev.isReady) || hasNewVisible) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _ensureDashboardDataLoaded(force: false);
          });
        }
      },
    );

    final cs = Theme.of(context).colorScheme;
    final showBlockingLoad = ref.watch(
      dashboardProvider.select(
        (s) => s.isLoading && s.monthly.isEmpty && s.yearly.isEmpty,
      ),
    );
    final vm = ref.read(dashboardProvider.notifier);
    final layoutState =
        ref.watch(managementDashboardLayoutCustomizationProvider);
    final layoutNotifier = ref.read(
      managementDashboardLayoutCustomizationProvider.notifier,
    );
    final padH = context.rsi(16);
    final gap = context.rsi(12);
    final visibleEntries = layoutState.visibleEntries
        .where((entry) => !_removingSectionIds.contains(entry.sectionId))
        .toList(growable: false);

    final dashboardBody = Skeletonizer(
      enabled: showBlockingLoad || !layoutState.isReady,
      child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: layoutState.isEditing
              ? Column(
                  key: const ValueKey('dashboard_edit_mode'),
                  children: [
                    Expanded(
                      child: ReorderableListView.builder(
                        key: _scrollStorageKey,
                        buildDefaultDragHandles: false,
                        physics: const AlwaysScrollableScrollPhysics(),
                        proxyDecorator: (child, index, animation) {
                          final curved = CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          );
                          return AnimatedBuilder(
                            animation: curved,
                            builder: (context, _) {
                              final t = curved.value;
                              return Transform.scale(
                                scale: 1.0 + (0.03 * t),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                  elevation: 3 + (7 * t),
                                  child: child,
                                ),
                              );
                            },
                          );
                        },
                        itemCount: visibleEntries.length,
                        padding: EdgeInsets.fromLTRB(
                          0,
                          gap,
                          0,
                          context.rsi(16),
                        ),
                        onReorder: layoutNotifier.reorderVisible,
                        itemBuilder: (context, index) {
                          final entry = visibleEntries[index];
                          final def = DashboardCustomizationRegistry.byId(
                              entry.sectionId);
                          final title = def?.title ?? entry.sectionId;
                          final subtitle =
                              _editSubtitleForSection(entry.sectionId);
                          return Padding(
                            key: ValueKey(entry.sectionId),
                            padding: EdgeInsets.only(bottom: gap),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              opacity:
                                  _removingSectionIds.contains(entry.sectionId)
                                      ? 0.0
                                      : 1.0,
                              child: _buildEditCompactCard(
                                context,
                                sectionId: entry.sectionId,
                                title: title,
                                subtitle: subtitle,
                                index: index,
                                canRemove:
                                    layoutNotifier.canRemove(entry.sectionId),
                                requiredSection: entry.pinned,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.rsi(16),
                          0,
                          context.rsi(16),
                          context.rsi(10),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () =>
                                _showAddSectionSheet(context, layoutState),
                            icon: const Icon(Icons.add),
                            label: const Text('섹션 추가'),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  key: _scrollStorageKey,
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(0, gap, 0, context.rsi(24)),
                  itemCount: visibleEntries.length,
                  separatorBuilder: (_, __) => SizedBox(height: gap),
                  itemBuilder: (context, index) {
                    final entry = visibleEntries[index];
                    return _buildSectionById(
                      sectionId: entry.sectionId,
                      context: context,
                      showBlockingLoad: showBlockingLoad,
                      cs: cs,
                      padH: padH,
                    );
                  },
                )),
    );
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('상황판'),
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (layoutState.isEditing) ...[
            IconButton(
              tooltip: '기본값 복원',
              onPressed: () {
                unawaited(layoutNotifier.resetToDefault());
              },
              icon: const Icon(Icons.settings_backup_restore_rounded),
            ),
            TextButton(
              onPressed: layoutNotifier.cancelEditing,
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                await layoutNotifier.saveEditing();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('대시보드 구성을 저장했습니다.')),
                );
              },
              child: const Text('완료'),
            ),
          ] else
            IconButton(
              tooltip: '대시보드 편집',
              onPressed: layoutState.isReady
                  ? () => unawaited(layoutNotifier.startEditing())
                  : null,
              icon: const Icon(Icons.edit_outlined),
            ),
          const NotificationBellButton(),
        ],
      ),
      body: layoutState.isEditing
          ? dashboardBody
          : AppRefreshIndicator(
              enabled: !showBlockingLoad && layoutState.isReady,
              onRefresh: () async {
                final visible = _visibleManagementSectionIds();
                if (visible.contains(DashboardSectionIds.managementKpi)) {
                  await vm.fetch(silent: true);
                }
                if (visible.contains(DashboardSectionIds.managementSchedule)) {
                  await ref.read(dashboardScheduleProvider.notifier).refresh();
                }
                if (visible.contains(DashboardSectionIds.managementDailyQuote)) {
                  await ref.read(todayDailyQuoteProvider.notifier).refresh();
                }
                if (visible
                    .contains(DashboardSectionIds.managementAnnouncement)) {
                  await _globalAnnouncementCardKey.currentState?.reloadPublic();
                }
              },
              child: dashboardBody,
            ),
    );
  }
}
