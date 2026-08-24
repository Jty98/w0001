import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_work_instruction_editor_sheet.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 캘린더 아래 — 선택일 요약 + 라벨이 있는 작업 액션.
class PlaceWorkforceDayToolbar extends StatelessWidget {
  const PlaceWorkforceDayToolbar({
    super.key,
    required this.selectedDay,
    required this.daySummary,
    required this.rosterListExpanded,
    required this.onToggleRosterList,
    required this.canEdit,
    required this.onAddProcess,
    required this.onAddWorkforceOnly,
    this.siteInstructionLoading = false,
    this.siteInstructionBlocks = const [],
    this.onEditSiteInstruction,
  });

  final DateTime selectedDay;
  final String daySummary;
  final bool rosterListExpanded;
  final VoidCallback onToggleRosterList;
  final bool canEdit;
  final VoidCallback onAddProcess;
  final VoidCallback onAddWorkforceOnly;
  final bool siteInstructionLoading;
  final List<WorkerAnnouncementBlock> siteInstructionBlocks;
  final VoidCallback? onEditSiteInstruction;

  bool get _hasSiteInstruction =>
      !workInstructionBlocksLookEmpty(siteInstructionBlocks);

  static String _dayHeadline(DateTime day) {
    final now = DateTime.now();
    final wd = getWeekDay(day.weekday);
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    final suffix = d == today
        ? ' · 오늘'
        : d == today.add(const Duration(days: 1))
            ? ' · 내일'
            : d == today.subtract(const Duration(days: 1))
                ? ' · 어제'
                : '';
    if (day.year == now.year) {
      return '${day.month}월 ${day.day}일 ($wd)$suffix';
    }
    return '${day.year}.${day.month}.${day.day} ($wd)$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(14),
              context.rsi(10),
              context.rsi(8),
              context.rsi(4),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dayHeadline(selectedDay),
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: context.rsi(2)),
                      Text(
                        daySummary,
                        style: tt.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onToggleRosterList,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.symmetric(horizontal: context.rsi(8)),
                    foregroundColor: cs.primary,
                    textStyle: tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(rosterListExpanded ? '목록 접기' : '목록 펼치기'),
                      Icon(
                        rosterListExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: context.rs(18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (canEdit) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.rsi(12),
                0,
                context.rsi(12),
                context.rsi(10),
              ),
              child: Row(
                children: [
                  // TODO(작업지시탭 이관): 현장 관리 탭 작업지시 버튼 — 삭제 예정
                  // Expanded(
                  //   child: _ActionChip(
                  //     icon: Icons.campaign_outlined,
                  //     label: _hasSiteInstruction ? '전체 지시' : '지시 작성',
                  //     emphasized: _hasSiteInstruction,
                  //     loading: siteInstructionLoading,
                  //     showDot: _hasSiteInstruction,
                  //     onPressed: siteInstructionLoading
                  //         ? null
                  //         : onEditSiteInstruction,
                  //   ),
                  // ),
                  // SizedBox(width: context.rsi(8)),
                  Expanded(
                    child: _ActionChip(
                      icon: Icons.add_task_outlined,
                      label: '공정 추가',
                      onPressed: onAddProcess,
                    ),
                  ),
                  SizedBox(width: context.rsi(8)),
                  Expanded(
                    child: _ActionChip(
                      icon: Icons.person_add_alt_1_outlined,
                      label: '인력 투입',
                      filled: true,
                      onPressed: onAddWorkforceOnly,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            SizedBox(height: context.rsi(6)),
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.emphasized = false,
    this.loading = false,
    this.showDot = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool emphasized;
  final bool loading;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(context.rs(12));

    final Color bg;
    final Color fg;
    final Color border;
    if (filled) {
      bg = enabled ? cs.primary : cs.surfaceContainerHighest;
      fg = enabled ? cs.onPrimary : cs.onSurfaceVariant;
      border = Colors.transparent;
    } else if (emphasized) {
      bg = cs.primary.withValues(alpha: 0.12);
      fg = cs.primary;
      border = cs.primary.withValues(alpha: 0.35);
    } else {
      bg = cs.appMutedFill.withValues(alpha: 0.85);
      fg = cs.onSurface;
      border = cs.outlineVariant.withValues(alpha: 0.55);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.rsi(6),
              vertical: context.rsi(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: context.rs(16),
                    height: context.rs(16),
                    child: const HammerLoadingIndicator(size: 16),
                  )
                else
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(icon, size: context.rs(17), color: fg),
                      if (showDot)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: filled ? cs.onPrimary : cs.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: filled ? cs.primary : cs.surface,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                SizedBox(width: context.rsi(5)),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
