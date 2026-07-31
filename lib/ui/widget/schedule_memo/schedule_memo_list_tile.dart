import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:w0001/data/model/schedule_memo_model.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart'
    show scheduleDateFromTaskKey;
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/util/responsive_layout.dart';

const _weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

const _saturdayBlue = Color(0xFF1565C0);
const _sundayRed = Color(0xFFD32F2F);

String _dayHeading(String taskDateKey) {
  final d = scheduleDateFromTaskKey(taskDateKey);
  final wd = _weekdayKo[d.weekday - 1];
  return '${d.month}/${d.day} ($wd)';
}

/// 관리자/작업자 일정 리스트 공통 타일.
///
/// - UI를 한 곳에서 관리하기 위해 대시보드의 기존 타일 구조를 그대로 옮겼습니다.
class ScheduleMemoListTile extends StatelessWidget {
  const ScheduleMemoListTile({
    super.key,
    required this.memo,
    required this.showDayHeading,
    required this.onDoneChanged,
    this.onTap,
    this.enableSlideActions = true,
    this.onEdit,
    this.onDelete,
    this.doneEnabled = true,
  });

  final ScheduleMemoModel memo;
  final bool showDayHeading;
  final VoidCallback? onTap;
  final ValueChanged<bool?> onDoneChanged;

  final bool enableSlideActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool doneEnabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final d = scheduleDateFromTaskKey(memo.taskDate);
    final isSat = d.weekday == DateTime.saturday;
    final isSun = d.weekday == DateTime.sunday;

    Color dayAccent;
    if (isSun) {
      dayAccent = _sundayRed;
    } else if (isSat) {
      dayAccent = _saturdayBlue;
    } else {
      dayAccent = cs.onSurfaceVariant;
    }

    final body = AppInsetTile(
      borderRadius: BorderRadius.circular(context.rsi(12)),
      padding: EdgeInsets.all(context.rsi(6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: memo.done,
            onChanged: doneEnabled ? onDoneChanged : null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: onTap == null
                ? Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: context.rsi(2),
                      horizontal: context.rsi(2),
                    ),
                    child: _memoContent(
                      context,
                      memo: memo,
                      showDayHeading: showDayHeading,
                      cs: cs,
                      tt: tt,
                      dayAccent: dayAccent,
                    ),
                  )
                : InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(context.rsi(8)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: context.rsi(2),
                        horizontal: context.rsi(2),
                      ),
                      child: _memoContent(
                        context,
                        memo: memo,
                        showDayHeading: showDayHeading,
                        cs: cs,
                        tt: tt,
                        dayAccent: dayAccent,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );

    if (!enableSlideActions) return body;

    return Slidable(
      key: ValueKey(
          memo.sid ?? '${memo.taskDate}-${memo.createdAtMs}-${memo.title}'),
      closeOnScroll: true,
      endActionPane: (onEdit == null && onDelete == null)
          ? null
          : ActionPane(
              motion: const DrawerMotion(),
              extentRatio: onEdit != null && onDelete != null ? 0.48 : 0.28,
              children: [
                if (onEdit != null)
                  SlidableAction(
                    onPressed: (_) => onEdit?.call(),
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    icon: Icons.edit_outlined,
                    label: '수정',
                    borderRadius: BorderRadius.circular(context.rsi(12)),
                  ),
                if (onDelete != null)
                  SlidableAction(
                    onPressed: (_) => onDelete?.call(),
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                    icon: Icons.delete_outline,
                    label: '삭제',
                    borderRadius: BorderRadius.circular(context.rsi(12)),
                  ),
              ],
            ),
      child: body,
    );
  }
}

Widget _memoContent(
  BuildContext context, {
  required ScheduleMemoModel memo,
  required bool showDayHeading,
  required ColorScheme cs,
  required TextTheme? tt,
  required Color dayAccent,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showDayHeading) ...[
        Text(
          _dayHeading(memo.taskDate),
          style: tt?.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: dayAccent,
          ),
        ),
        SizedBox(height: context.rsi(4)),
      ],
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  memo.title.trim().isEmpty ? '(제목 없음)' : memo.title.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt?.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    decoration: memo.done ? TextDecoration.lineThrough : null,
                    color: memo.done ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                ),
                if (memo.memo.trim().isNotEmpty) ...[
                  SizedBox(height: context.rsi(4)),
                  Text(
                    memo.memo.trim(),
                    style: tt?.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (memo.taskTime.trim().isNotEmpty || memo.alarmEnabled) ...[
            SizedBox(width: context.rsi(10)),
            SizedBox(
              width: context.rs(110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (memo.taskTime.trim().isNotEmpty)
                    Text(
                      memo.taskTime.trim(),
                      textAlign: TextAlign.right,
                      style: tt?.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                        height: 1.0,
                      ),
                    ),
                  if (memo.alarmEnabled) ...[
                    SizedBox(height: context.rsi(6)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rsi(8),
                        vertical: context.rsi(3),
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '알람',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt?.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    ],
  );
}
