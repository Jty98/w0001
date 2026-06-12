import 'package:flutter/material.dart';
import 'package:w0001/domain/process_schedule/process_schedule_editor.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/domain/process_schedule/process_schedule_palette.dart';
import 'package:w0001/util/responsive_layout.dart';

import 'process_schedule_dim.dart';
import 'process_schedule_helpers.dart';

Color neutralScheduleCell(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return cs.surfaceContainerLow;
}

Color onBarLabelColor(ColorScheme cs, Color bar) {
  return bar.computeLuminance() > 0.55 ? cs.onSurface : cs.onPrimary;
}

Widget cornerHeader(BuildContext context, ColorScheme cs) {
  final tt = Theme.of(context).textTheme;
  return SizedBox(
    width: ProcessScheduleChartDim.leftColW(context),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.surfaceContainerHigh.withValues(alpha: 0.95),
            cs.surfaceContainerHighest.withValues(alpha: 0.88),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: Center(
        child: Text(
          '구분',
          textAlign: TextAlign.center,
          style: tt.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
      ),
    ),
  );
}

Widget dateHeaderCell(
  BuildContext context,
  DateTime day, {
  VoidCallback? onTap,
}) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final isWeekend =
      day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
  final inner = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          cs.surfaceContainerHigh.withValues(alpha: 0.92),
          cs.surfaceContainer.withValues(alpha: 0.85),
        ],
      ),
      border: Border(
        bottom: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.45),
        ),
        right: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${day.day}',
            style: tt.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: isWeekend
                  ? (day.weekday == DateTime.sunday ? cs.error : cs.primary)
                  : cs.onSurface,
            ),
          ),
          Text(
            weekdayKoShort(day.weekday),
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
  return SizedBox(
    width: ProcessScheduleChartDim.cellW(context),
    height: double.infinity,
    child: onTap == null
        ? inner
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: inner,
            ),
          ),
  );
}

Widget taskLabelCell(
  BuildContext context,
  ProcessScheduleTask row, {
  VoidCallback? onLongPress,
}) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final bar = Color(ProcessSchedulePalette.argbAt(row.paletteIndex));

  final content = DecoratedBox(
    decoration: BoxDecoration(
      color: cs.surfaceContainerHigh.withValues(alpha: 0.88),
      border: Border(
        right: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.45),
        ),
        bottom: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: context.rs(5),
          decoration: BoxDecoration(
            color: bar,
            borderRadius: BorderRadius.horizontal(
              right: Radius.circular(context.rs(2)),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: ResponsiveLayout.only(
              context,
              left: 8,
              right: 6,
            ),
            child: Text(
              row.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                height: 1.15,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  if (onLongPress == null) {
    return content;
  }

  return Material(
    color: Colors.transparent,
    child: InkWell(
      onLongPress: onLongPress,
      child: content,
    ),
  );
}

TableCell scheduleGridCell({
  required BuildContext context,
  required ProcessScheduleData data,
  required int taskIndex,
  required int dayIndex,
  required Set<int> labelCenterDays,

  /// `true`(헤더 고정): 표 위 오버레이가 탭·롱프레스 처리 — 셀 InkWell 없음.
  required bool gesturesHandledAbove,
  VoidCallback? onTapInCell,
}) {
  final row = data.tasks[taskIndex];
  final on = row.scheduledDayIndices.contains(dayIndex);
  final bar = Color(ProcessSchedulePalette.argbAt(row.paletteIndex));
  final fill = on ? bar.withValues(alpha: 0.92) : neutralScheduleCell(context);
  final showLabel = on && labelCenterDays.contains(dayIndex);
  final scheme = Theme.of(context).colorScheme;
  final labelColor = onBarLabelColor(scheme, bar);
  final dates = ProcessScheduleEditor.columnDates(data);
  final day = dates[dayIndex];
  final tt = Theme.of(context).textTheme;

  final semanticsHint = gesturesHandledAbove
      ? (on
          ? '일정 있음. 탭 한 번 또는 길게 눌러 연속 칠하기·지우기'
          : '일정 없음. 탭 한 번 또는 길게 눌러 연속 칠하기·지우기')
      : (on ? '일정 있음, 탭하면 해제' : '일정 없음, 탭하면 등록');

  Widget core = SizedBox(
    height: ProcessScheduleChartDim.cellH(context),
    width: ProcessScheduleChartDim.cellW(context),
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (showLabel)
          IgnorePointer(
            child: Padding(
              padding: ResponsiveLayout.symmetric(context, horizontal: 1),
              child: Text(
                row.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  color: labelColor,
                  shadows: [
                    Shadow(
                      color: labelColor == scheme.onPrimary
                          ? scheme.shadow.withValues(alpha: 0.42)
                          : scheme.outline.withValues(alpha: 0.45),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );

  if (!gesturesHandledAbove && onTapInCell != null) {
    core = InkWell(
      onTap: onTapInCell,
      child: core,
    );
  }

  return TableCell(
    child: Semantics(
      label: '${row.name}, ${day.month}월 ${day.day}일',
      hint: semanticsHint,
      child: DecoratedBox(
        decoration: BoxDecoration(color: fill),
        child: core,
      ),
    ),
  );
}
