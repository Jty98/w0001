import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/domain/dashboard_customization.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_layout_customization_provider.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/daily_quote_providers.dart';
import 'package:w0001/presentation/viewmodel/place_checklist_notifier.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/worker_schedule_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_personal_dashboard_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_paged_list_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_supply_map_providers.dart';
import 'package:w0001/theme/app_elevation.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/assignment_instruction_detail_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/schedule_memo_editor_shared.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/daily_quote_dashboard_section.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/worker_dashboard_checklist_section.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/worker_dashboard_global_announcement_section.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/worker_dashboard_section_shell.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_section_preview_tile.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_blocks_display.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/map_route_action_buttons.dart';
import 'package:w0001/presentation/viewmodel/user_notifications_providers.dart';
import 'package:w0001/ui/widget/notification_bell_button.dart';
import 'package:w0001/util/map_navigation_launcher.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/funtions.dart';

const _weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

String _todayTitleLine() {
  final d = DateTime.now();
  return '${d.year}년 ${d.month}월 ${d.day}일 (${_weekdayKo[d.weekday - 1]})';
}

ScheduleMemoRead _workerDashSkeletonMemo({required bool assignment}) {
  final d = DateTime.now();
  final k = scheduleDateKey(scheduleDateOnly(d));
  return ScheduleMemoRead(
    sid: -1,
    taskdate: k,
    tasktime: assignment ? '09:00' : '14:00',
    title: assignment ? '현장 배정' : '직접 일정',
    memo: assignment ? '' : '오늘 메모 내용이 여기에 표시됩니다.',
    done: false,
    alarmenabled: false,
    sortorder: 0,
    createdatms: 0,
    sourceType: assignment ? 'assignment' : 'manual',
    workrole: assignment ? '목공' : '',
  );
}

List<WorkerAnnouncementBlock> _dashMemoRichBlocks(ScheduleMemoRead m) {
  if (m.instructionBlocks.isNotEmpty) return m.instructionBlocks;
  final memo = m.memo.trim();
  if (memo.isNotEmpty &&
      WorkerAnnouncementQuillCodec.isQuillEnvelopeText(memo)) {
    return [WorkerAnnouncementTextBlock(memo)];
  }
  return const [];
}

bool _dashMemoHasPlain(ScheduleMemoRead m) {
  final memo = m.memo.trim();
  if (memo.isEmpty) return false;
  return !WorkerAnnouncementQuillCodec.isQuillEnvelopeText(memo);
}

bool _dashMemoPlainVisible(
    ScheduleMemoRead m, List<WorkerAnnouncementBlock> rich) {
  if (!_dashMemoHasPlain(m)) return false;
  if (m.isAssignment && rich.isNotEmpty) return false;
  return true;
}

/// 작업자 전용 — `GET /worker/dashboard/summary` 기반(관리자 상황판과 별도).
class WorkerPersonalDashboardScreen extends ConsumerStatefulWidget {
  const WorkerPersonalDashboardScreen({super.key});

  @override
  ConsumerState<WorkerPersonalDashboardScreen> createState() =>
      _WorkerPersonalDashboardScreenState();
}

class _WorkerPersonalDashboardScreenState
    extends ConsumerState<WorkerPersonalDashboardScreen> {
  final Set<String> _removingSectionIds = <String>{};

  Set<String> _visibleWorkerSectionIds() {
    final layout = ref.read(workerDashboardLayoutCustomizationProvider);
    if (!layout.isReady) return const <String>{};
    return layout.visibleEntries.map((e) => e.sectionId).toSet();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSessionIfNeeded();
      ref.invalidate(userNotificationInboxProvider);
    });
  }

  void _loadSessionIfNeeded() {
    if (!mounted) return;
    final s = ref.read(authSessionProvider);
    if (s.isLoading) return;
    if (s.maybeWhen(data: (u) => u != null, orElse: () => false)) return;
    ref.read(authSessionProvider.notifier).loadCurrentUser();
  }

  Future<void> _reloadDashboardContent({
    required Set<String> visibleSectionIds,
  }) async {
    final futures = <Future<void>>[];
    if (visibleSectionIds.contains(DashboardSectionIds.workerTodaySchedule)) {
      futures.add(ref.read(workerScheduleNotifierProvider.notifier).reload());
      futures.add(ref.read(placeListProvider.notifier).initialize());
    }
    if (visibleSectionIds.contains(DashboardSectionIds.workerChecklist)) {
      futures.add(ref.read(placeListProvider.notifier).initialize(force: true));
    }
    if (visibleSectionIds.contains(DashboardSectionIds.workerAnnouncement)) {
      futures.add(
        ref
            .read(workerDashboardGlobalAnnouncementPreviewProvider.notifier)
            .reload(silent: true),
      );
    }
    if (visibleSectionIds.contains(DashboardSectionIds.workerEarnings)) {
      futures.add(
        ref.read(workerPersonalDashboardProvider.notifier).reload(silent: true),
      );
    }
    if (visibleSectionIds.contains(DashboardSectionIds.workerWelcomeBanner)) {
      futures.add(ref.read(todayDailyQuoteProvider.notifier).refresh());
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
    if (!visibleSectionIds.contains(DashboardSectionIds.workerChecklist)) {
      return;
    }
    final places = ref.read(placeListProvider).placeList.where(
          (p) => p.pcomplete == 0 && (p.pid ?? 0) > 0,
        );
    await Future.wait(
      places.map(
        (p) => ref
            .read(
              placeChecklistProvider((
                pid: p.pid ?? 0,
                pstart: p.pstart,
                pend: p.pend,
              )).notifier,
            )
            .load(),
      ),
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
      DashboardLayoutRoleScope.worker,
    )
        .where((section) => hiddenIds.contains(section.id))
        .toList(growable: false);
  }

  Future<void> _showAddSectionSheet(
    BuildContext context,
    DashboardLayoutCustomizationState layoutState,
  ) async {
    final notifier =
        ref.read(workerDashboardLayoutCustomizationProvider.notifier);
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
                notifier.restoreSection(section.id);
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
    required ThemeData theme,
    required ColorScheme cs,
    required String? greetingName,
  }) {
    switch (sectionId) {
      case DashboardSectionIds.workerWelcomeBanner:
        if (greetingName == null || greetingName.isEmpty) {
          return const SizedBox.shrink();
        }
        return WorkerWelcomeQuoteBanner(name: greetingName);
      case DashboardSectionIds.workerAnnouncement:
        return const WorkerDashboardGlobalAnnouncementSection();
      case DashboardSectionIds.workerEarnings:
        return _buildEarningsSummarySection(theme, cs);
      case DashboardSectionIds.workerTodaySchedule:
        return _buildTodayScheduleSection(theme, cs);
      case DashboardSectionIds.workerChecklist:
        return const WorkerDashboardChecklistSection();
      default:
        return const SizedBox.shrink();
    }
  }

  String _editSubtitleForSection(String sectionId) {
    switch (sectionId) {
      case DashboardSectionIds.workerWelcomeBanner:
        return '인사/문구 영역';
      case DashboardSectionIds.workerAnnouncement:
        return '공지 요약';
      case DashboardSectionIds.workerEarnings:
        return '정산 요약';
      case DashboardSectionIds.workerTodaySchedule:
        return '오늘 일정 요약';
      case DashboardSectionIds.workerChecklist:
        return '체크리스트 요약';
      default:
        return '';
    }
  }

  DashboardSectionPreviewKind _previewKindForSection(String sectionId) {
    switch (sectionId) {
      case DashboardSectionIds.workerWelcomeBanner:
        return DashboardSectionPreviewKind.welcome;
      case DashboardSectionIds.workerAnnouncement:
        return DashboardSectionPreviewKind.announcement;
      case DashboardSectionIds.workerEarnings:
        return DashboardSectionPreviewKind.kpi;
      case DashboardSectionIds.workerTodaySchedule:
        return DashboardSectionPreviewKind.today;
      case DashboardSectionIds.workerChecklist:
        return DashboardSectionPreviewKind.checklist;
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
                      Expanded(child: _compactLine(context, 0.84)),
                      SizedBox(width: context.rsi(8)),
                      Expanded(child: _compactLine(context, 0.58)),
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
                      _removeWithAnimation(sectionId, title);
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

  Future<void> _removeWithAnimation(String sectionId, String title) async {
    if (_removingSectionIds.contains(sectionId)) return;
    setState(() {
      _removingSectionIds.add(sectionId);
    });
    await Future<void>.delayed(const Duration(milliseconds: 170));
    final notifier =
        ref.read(workerDashboardLayoutCustomizationProvider.notifier);
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
            notifier.restoreSection(sectionId);
          },
        ),
      ),
    );
  }

  Widget _personalDashboardSkeletonList(
    ThemeData theme,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return Skeletonizer(
      enabled: true,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          context.rsi(16),
          context.rsi(12),
          context.rsi(16),
          MediaQuery.viewPaddingOf(context).bottom + context.rsi(32),
        ),
        children: [
          const WorkerWelcomeQuoteBanner(name: '표시 이름'),
          SizedBox(height: context.rsi(20)),
          const WorkerDashboardGlobalAnnouncementSection(),
          SizedBox(height: context.rsi(20)),
          WorkerDashboardSectionShell(
            icon: Icons.wb_sunny_outlined,
            title: '오늘 일정',
            subtitle: _todayTitleLine(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TodayMemoTile(
                  memo: _workerDashSkeletonMemo(assignment: true),
                  cs: cs,
                  tt: tt,
                ),
                SizedBox(height: context.rsi(12)),
                _TodayMemoTile(
                  memo: _workerDashSkeletonMemo(assignment: false),
                  cs: cs,
                  tt: tt,
                ),
              ],
            ),
          ),
          SizedBox(height: context.rsi(20)),
          const WorkerDashboardChecklistSection(),
        ],
      ),
    );
  }

  Widget _buildTodayScheduleSection(ThemeData theme, ColorScheme cs) {
    final tt = theme.textTheme;
    final asyncMemos = ref.watch(workerScheduleNotifierProvider);
    final placeState = ref.watch(placeListProvider);
    final todayKey = scheduleDateKey(scheduleDateOnly(DateTime.now()));
    final placeByPid = <int, PlaceInfoModel>{
      for (final p in placeState.placeList)
        if ((p.pid ?? 0) > 0) p.pid!: p,
    };

    return WorkerDashboardSectionShell(
      icon: Icons.wb_sunny_outlined,
      title: '오늘 일정',
      subtitle: _todayTitleLine(),
      child: asyncMemos.when(
        loading: () => Skeletonizer(
          enabled: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TodayMemoTile(
                memo: _workerDashSkeletonMemo(assignment: true),
                cs: cs,
                tt: tt,
              ),
              SizedBox(height: context.rsi(12)),
              _TodayMemoTile(
                memo: _workerDashSkeletonMemo(assignment: false),
                cs: cs,
                tt: tt,
              ),
            ],
          ),
        ),
        error: (e, _) => Text(
          '오늘 일정을 불러오지 못했습니다.\n$e',
          style: tt.bodySmall?.copyWith(color: cs.error, height: 1.35),
        ),
        data: (memos) {
          final items = memos.where((m) {
            final d = m.taskdate.length >= 10
                ? m.taskdate.substring(0, 10)
                : m.taskdate;
            return d == todayKey;
          }).toList()
            ..sort((a, b) {
              if (a.isAssignment != b.isAssignment) {
                return a.isAssignment ? -1 : 1;
              }
              return a.sortorder.compareTo(b.sortorder);
            });

          if (items.isEmpty) {
            return Text(
              '오늘 등록된 일정이 없습니다.\n내 일정 탭에서 추가하거나 배정 내역을 확인하세요.',
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) SizedBox(height: context.rsi(12)),
                _TodayMemoTile(
                  memo: items[i],
                  cs: cs,
                  tt: tt,
                  assignmentAddress: items[i].isAssignment
                      ? (placeByPid[items[i].placePid ?? -1]?.paddress ?? '')
                      : '',
                  onTap: items[i].isAssignment
                      ? () => showAssignmentInstructionDetailSheet(
                            context,
                            items[i],
                          )
                      : null,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEarningsSummarySection(ThemeData theme, ColorScheme cs) {
    final tt = theme.textTheme;
    final query = ref.watch(workerDashboardQueryProvider);
    final taxState = ref.watch(workerDashboardTaxStateProvider);
    final isTaxApply = taxState == TaxState.taxOn;
    final asyncData = ref.watch(workerPersonalDashboardProvider);

    return WorkerDashboardSectionShell(
      icon: Icons.payments_outlined,
      title: '근로 · 정산',
      subtitle: query.isMonthly
          ? '${query.year}년 ${query.month}월'
          : '${query.year}년 전체',
      child: asyncData.when(
        loading: () => _earningsSummarySkeleton(context),
        error: (_, __) => Text(
          '정산 요약을 불러오지 못했습니다.',
          style: tt.bodySmall?.copyWith(color: cs.error),
        ),
        data: (data) {
          final totals = data.displayMonthTotals ?? data.displayYearTotals;
          if (totals == null) {
            return Text(
              '표시할 근로 정산 데이터가 없습니다.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _earningsPill(
                      context,
                      label: '일한 금액',
                      value: totals.totalEarned,
                      isTaxApply: isTaxApply,
                      tone: cs.onSurface,
                    ),
                  ),
                  SizedBox(width: context.rsi(8)),
                  Expanded(
                    child: _earningsPill(
                      context,
                      label: '미정산액',
                      value: totals.totalOutstanding,
                      isTaxApply: isTaxApply,
                      tone:
                          totals.totalOutstanding > 0 ? cs.error : cs.onSurface,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rsi(10)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isTaxApply ? '세후(3.3% 반영)' : '세전 표시',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/settings/earnings'),
                    child: const Text('자세히 보기'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _earningsSummarySkeleton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Skeletonizer(
      enabled: true,
      child: Row(
        children: [
          Expanded(
            child: _earningsPill(
              context,
              label: '일한 금액',
              value: 2400000,
              isTaxApply: true,
              tone: cs.onSurface,
            ),
          ),
          SizedBox(width: context.rsi(8)),
          Expanded(
            child: _earningsPill(
              context,
              label: '미정산액',
              value: 800000,
              isTaxApply: true,
              tone: cs.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _earningsPill(
    BuildContext context, {
    required String label,
    required int value,
    required bool isTaxApply,
    required Color tone,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: AppElevation.insetTile(
        context: context,
        backgroundColor: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.rsi(10),
          vertical: context.rsi(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: context.rsi(6)),
            Text(
              getPrice(
                  price: value, isTaxApply: isTaxApply, isContainWon: false),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.titleSmall?.copyWith(
                color: tone,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final auth = ref.watch(authSessionProvider);
    final user = auth.asData?.value;
    final greetingName = user?.uname.trim();
    final layoutState = ref.watch(workerDashboardLayoutCustomizationProvider);
    final layoutNotifier =
        ref.read(workerDashboardLayoutCustomizationProvider.notifier);
    final visibleEntries = layoutState.visibleEntries
        .where((entry) => !_removingSectionIds.contains(entry.sectionId))
        .toList(growable: false);

    final dashboardBody = auth.isLoading
        ? _personalDashboardSkeletonList(theme, cs, tt)
        : user != null && !user.isWorker
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(context.rsi(24)),
                children: [
                  Text(
                    '작업자 계정에서만 이용할 수 있습니다.',
                    style: tt.bodyLarge?.copyWith(color: cs.error),
                  ),
                ],
              )
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: layoutState.isEditing
                    ? Column(
                        key: const ValueKey('worker_dashboard_edit_mode'),
                        children: [
                          Expanded(
                            child: ReorderableListView.builder(
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
                              padding: EdgeInsets.fromLTRB(
                                context.rsi(16),
                                context.rsi(12),
                                context.rsi(16),
                                context.rsi(12),
                              ),
                              itemCount: visibleEntries.length,
                              onReorder: layoutNotifier.reorderVisible,
                              itemBuilder: (context, index) {
                                final entry = visibleEntries[index];
                                final def = DashboardCustomizationRegistry.byId(
                                  entry.sectionId,
                                );
                                final title = def?.title ?? entry.sectionId;
                                final subtitle =
                                    _editSubtitleForSection(entry.sectionId);
                                return Container(
                                  key: ValueKey(entry.sectionId),
                                  margin:
                                      EdgeInsets.only(bottom: context.rsi(14)),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    opacity: _removingSectionIds
                                            .contains(entry.sectionId)
                                        ? 0.0
                                        : 1.0,
                                    child: _buildEditCompactCard(
                                      context,
                                      sectionId: entry.sectionId,
                                      title: title,
                                      subtitle: subtitle,
                                      index: index,
                                      canRemove: layoutNotifier
                                          .canRemove(entry.sectionId),
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
                        key: const ValueKey('worker_dashboard_view_mode'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          context.rsi(16),
                          context.rsi(12),
                          context.rsi(16),
                          MediaQuery.viewPaddingOf(context).bottom +
                              context.rsi(32),
                        ),
                        itemCount: visibleEntries.length,
                        separatorBuilder: (_, __) => SizedBox(
                          height: context.rsi(20),
                        ),
                        itemBuilder: (context, index) {
                          final entry = visibleEntries[index];
                          return _buildSectionById(
                            sectionId: entry.sectionId,
                            theme: theme,
                            cs: cs,
                            greetingName: greetingName,
                          );
                        },
                      ));
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('내 근로 현황'),
        actions: [
          if (layoutState.isEditing) ...[
            IconButton(
              tooltip: '기본값 복원',
              onPressed: () {
                layoutNotifier.resetToDefault();
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
                if (!context.mounted) return;
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
                  ? () => layoutNotifier.startEditing()
                  : null,
              icon: const Icon(Icons.edit_outlined),
            ),
          const NotificationBellButton(),
        ],
      ),
      body: layoutState.isEditing
          ? dashboardBody
          : AppRefreshIndicator(
              enabled: !auth.isLoading && layoutState.isReady,
              onRefresh: () => _reloadDashboardContent(
                visibleSectionIds: _visibleWorkerSectionIds(),
              ),
              child: dashboardBody,
            ),
    );
  }
}

class _TodayMemoTile extends ConsumerWidget {
  const _TodayMemoTile({
    required this.memo,
    required this.cs,
    required this.tt,
    this.assignmentAddress = '',
    this.onTap,
  });

  final ScheduleMemoRead memo;
  final ColorScheme cs;
  final TextTheme tt;
  final String assignmentAddress;
  final VoidCallback? onTap;

  Future<void> _copyAddress(BuildContext context) async {
    final text = assignmentAddress.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('현장 주소를 복사했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (memo.isAssignment) {
      final rich = _dashMemoRichBlocks(memo);
      final radius = BorderRadius.circular(12);
      return DecoratedBox(
        decoration: AppElevation.insetTile(
          context: context,
          backgroundColor: cs.appInsetFill,
          borderRadius: radius,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(14),
              context.rsi(12),
              context.rsi(14),
              context.rsi(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.work_outline_rounded, color: cs.primary),
                    SizedBox(width: context.rsi(10)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          scheduleMemoListTitleRow(
                            context,
                            title: memo.title.trim().isEmpty
                                ? '현장 배정'
                                : memo.title.trim(),
                            tasktimeRaw: memo.tasktime,
                            titleStyle: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                              color: cs.onSurface,
                            ),
                          ),
                          if (memo.workrole.trim().isNotEmpty) ...[
                            SizedBox(height: context.rsi(6)),
                            Text(
                              '역할 [${memo.workrole.trim()}]',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (rich.isNotEmpty) ...[
                  SizedBox(height: context.rsi(10)),
                  Text(
                    '작업 내용',
                    style: tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  SizedBox(height: context.rsi(6)),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      context.rsi(10),
                      context.rsi(8),
                      context.rsi(10),
                      context.rsi(8),
                    ),
                    decoration: BoxDecoration(
                      color: cs.appMutedFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.appBorder),
                    ),
                    child: SizedBox(
                      height: context.rs(120),
                      child: IgnorePointer(
                        child: WorkerAnnouncementBlocksDisplay(
                          blocks: rich,
                          suppressInteractiveImageMenu: true,
                          quillViewportMaxHeight: 118,
                        ),
                      ),
                    ),
                  ),
                ] else if (_dashMemoPlainVisible(memo, rich)) ...[
                  SizedBox(height: context.rsi(8)),
                  Text(
                    memo.memo.trim(),
                    style: tt.bodyMedium?.copyWith(
                      height: 1.35,
                      color: cs.onSurface,
                    ),
                  ),
                ],
                if (assignmentAddress.trim().isNotEmpty) ...[
                  SizedBox(height: context.rsi(10)),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      context.rsi(10),
                      context.rsi(9),
                      context.rsi(10),
                      context.rsi(9),
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: context.rsi(16),
                              color: cs.primary,
                            ),
                            SizedBox(width: context.rsi(6)),
                            Expanded(
                              child: Text(
                                assignmentAddress.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: context.rsi(8)),
                        MapRouteActionButtons(
                          compact: true,
                          onCopyAddress: () => _copyAddress(context),
                          onKakao: () async {
                            final address = assignmentAddress.trim();
                            final query = '${memo.title} $address'.trim();
                            final kakaoLocal =
                                ref.read(kakaoLocalMapApiProvider);
                            final resolved = await kakaoLocal.resolveBestMatch(
                              address: address,
                              keyword: memo.title,
                            );
                            if (resolved != null) {
                              await MapNavigationLauncher.openKakaoNaviRoute(
                                destinationName: resolved.name.trim().isEmpty
                                    ? query
                                    : resolved.name,
                                latitude: resolved.latitude,
                                longitude: resolved.longitude,
                              );
                              return;
                            }
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('경로 좌표를 찾지 못해 카카오내비 안내를 시작할 수 없습니다.'),
                              ),
                            );
                          },
                          onTmap: () async {
                            final query =
                                '${memo.title} ${assignmentAddress.trim()}';
                            await MapNavigationLauncher.openTmapSearch(query);
                          },
                        ),
                        SizedBox(height: context.rsi(4)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: AppElevation.insetTile(
        context: context,
        backgroundColor: cs.appInsetFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(14),
          context.rsi(12),
          context.rsi(14),
          context.rsi(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_note_outlined, color: cs.primary),
                SizedBox(width: context.rsi(10)),
                Expanded(
                  child: scheduleMemoListTitleRow(
                    context,
                    title: memo.title.trim().isEmpty
                        ? '(제목 없음)'
                        : memo.title.trim(),
                    tasktimeRaw: memo.tasktime,
                    titleStyle: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (memo.memo.trim().isNotEmpty) ...[
              SizedBox(height: context.rsi(8)),
              Text(
                memo.memo.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(
                  height: 1.35,
                  color: cs.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
