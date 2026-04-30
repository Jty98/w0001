import 'package:flutter/material.dart';
import 'package:w0001/domain/process_schedule/process_schedule_editor.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/domain/process_schedule/process_schedule_palette.dart';

import 'process_schedule_dim.dart';
import 'process_schedule_helpers.dart';

Color neutralScheduleCell(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Color.lerp(cs.surface, Colors.white, 0.65)!;
}

Color onBarLabelColor(Color bar) {
  return bar.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
}

Widget cornerHeader(ColorScheme cs) {
  return SizedBox(
    width: ProcessScheduleChartDim.leftColW,
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
      ),
    ),
  );
}

Widget dateHeaderCell(BuildContext context, DateTime day) {
  final cs = Theme.of(context).colorScheme;
  final isWeekend =
      day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
  return SizedBox(
    width: ProcessScheduleChartDim.cellW,
    child: DecoratedBox(
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isWeekend
                    ? (day.weekday == DateTime.sunday
                        ? Colors.red[700]
                        : Colors.blue[800])
                    : cs.onSurface,
              ),
            ),
            Text(
              weekdayKoShort(day.weekday),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget taskLabelCell(BuildContext context, ProcessScheduleTask row) {
  final cs = Theme.of(context).colorScheme;
  final bar = Color(ProcessSchedulePalette.argbAt(row.paletteIndex));
  return DecoratedBox(
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
          width: 5,
          decoration: BoxDecoration(
            color: bar,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(2),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 6),
            child: Text(
              row.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
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
  final labelColor = onBarLabelColor(bar);
  final dates = ProcessScheduleEditor.columnDates(data);
  final day = dates[dayIndex];

  final semanticsHint = gesturesHandledAbove
      ? (on ? '일정 있음. 탭 한 번 또는 길게 눌러 연속 칠하기·지우기' : '일정 없음. 탭 한 번 또는 길게 눌러 연속 칠하기·지우기')
      : (on ? '일정 있음, 탭하면 해제' : '일정 없음, 탭하면 등록');

  Widget core = SizedBox(
    height: ProcessScheduleChartDim.cellH,
    width: ProcessScheduleChartDim.cellW,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (showLabel)
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Text(
                row.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  color: labelColor,
                  shadows: [
                    Shadow(
                      color: labelColor == Colors.white
                          ? Colors.black54
                          : Colors.white70,
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
    verticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
    child: Material(
      color: fill,
      child: Semantics(
        button: true,
        label:
            '${row.name} ${day.month}/${day.day}, $semanticsHint',
        child: core,
      ),
    ),
  );
}
