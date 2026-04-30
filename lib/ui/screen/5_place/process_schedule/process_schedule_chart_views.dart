import 'package:flutter/material.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';

import 'process_schedule_dim.dart';
import 'process_schedule_grid_widgets.dart';

/// 스크롤 동기화된 헤더 고정 공정표.
/// 표 영역 상단 [Listener]가 탭·롱프레스·드래그(연속 칠하기)를 처리합니다.
class ProcessScheduleStickyScrollChart extends StatelessWidget {
  const ProcessScheduleStickyScrollChart({
    super.key,
    required this.cs,
    required this.data,
    required this.dates,
    required this.labelCentersByRow,
    required this.hHeader,
    required this.hBody,
    required this.vLeft,
    required this.vBody,
    required this.brushScrollLock,
    required this.onStickyPointerDown,
    required this.onStickyPointerMove,
    required this.onStickyPointerUp,
    required this.onStickyPointerCancel,
  });

  final ColorScheme cs;
  final ProcessScheduleData data;
  final List<DateTime> dates;
  final List<Set<int>> labelCentersByRow;

  final ScrollController hHeader;
  final ScrollController hBody;
  final ScrollController vLeft;
  final ScrollController vBody;

  final bool brushScrollLock;

  final void Function(PointerDownEvent e) onStickyPointerDown;
  final void Function(PointerMoveEvent e) onStickyPointerMove;
  final void Function(PointerUpEvent e) onStickyPointerUp;
  final VoidCallback onStickyPointerCancel;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final tableBody = SizedBox(
      width: d.dayCount * ProcessScheduleChartDim.cellW,
      height: d.tasks.length * ProcessScheduleChartDim.cellH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Table(
            defaultColumnWidth:
                const FixedColumnWidth(ProcessScheduleChartDim.cellW),
            border: TableBorder.all(
              color: cs.outlineVariant.withValues(alpha: 0.35),
              width: 0.5,
            ),
            children: [
              for (var ti = 0; ti < d.tasks.length; ti++)
                TableRow(
                  children: [
                    for (var di = 0; di < d.dayCount; di++)
                      scheduleGridCell(
                        context: context,
                        data: d,
                        taskIndex: ti,
                        dayIndex: di,
                        labelCenterDays: labelCentersByRow[ti],
                        gesturesHandledAbove: true,
                      ),
                  ],
                ),
            ],
          ),
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: onStickyPointerDown,
              onPointerMove: onStickyPointerMove,
              onPointerUp: onStickyPointerUp,
              onPointerCancel: (_) => onStickyPointerCancel(),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: ProcessScheduleChartDim.headerH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cornerHeader(cs),
              Expanded(
                child: ListView.builder(
                  controller: hHeader,
                  padding: EdgeInsets.zero,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: dates.length,
                  itemBuilder: (ctx, i) =>
                      dateHeaderCell(context, dates[i]),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: ProcessScheduleChartDim.leftColW,
                child: ListView.builder(
                  controller: vLeft,
                  physics: const ClampingScrollPhysics(),
                  itemCount: d.tasks.length,
                  itemExtent: ProcessScheduleChartDim.cellH,
                  itemBuilder: (ctx, i) =>
                      taskLabelCell(context, d.tasks[i]),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: vBody,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: vBody,
                    physics: brushScrollLock
                        ? const NeverScrollableScrollPhysics()
                        : const ClampingScrollPhysics(),
                    child: Scrollbar(
                      controller: hBody,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: hBody,
                        scrollDirection: Axis.horizontal,
                        physics: brushScrollLock
                            ? const NeverScrollableScrollPhysics()
                            : const ClampingScrollPhysics(),
                        child: tableBody,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

double chartContentW(ProcessScheduleData d) =>
    ProcessScheduleChartDim.leftColW + d.dayCount * ProcessScheduleChartDim.cellW;

double chartContentH(ProcessScheduleData d) =>
    ProcessScheduleChartDim.headerH +
    d.tasks.length * ProcessScheduleChartDim.cellH;

/// InteractiveViewer 안에 들어가는 고정 크기 표 — 셀 탭만 지원.
class ProcessScheduleOverviewChart extends StatelessWidget {
  const ProcessScheduleOverviewChart({
    super.key,
    required this.cs,
    required this.data,
    required this.dates,
    required this.labelCentersByRow,
    required this.onCellTap,
  });

  final ColorScheme cs;
  final ProcessScheduleData data;
  final List<DateTime> dates;
  final List<Set<int>> labelCentersByRow;

  final void Function(int taskIndex, int dayIndex) onCellTap;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return SizedBox(
      width: chartContentW(d),
      height: chartContentH(d),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: ProcessScheduleChartDim.headerH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cornerHeader(cs),
                for (var i = 0; i < dates.length; i++)
                  SizedBox(
                    width: ProcessScheduleChartDim.cellW,
                    height: ProcessScheduleChartDim.headerH,
                    child: dateHeaderCell(context, dates[i]),
                  ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: ProcessScheduleChartDim.leftColW,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in d.tasks)
                      SizedBox(
                        height: ProcessScheduleChartDim.cellH,
                        width: ProcessScheduleChartDim.leftColW,
                        child: taskLabelCell(context, t),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: d.dayCount * ProcessScheduleChartDim.cellW,
                height: d.tasks.length * ProcessScheduleChartDim.cellH,
                child: Table(
                  defaultColumnWidth:
                      const FixedColumnWidth(ProcessScheduleChartDim.cellW),
                  border: TableBorder.all(
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                    width: 0.5,
                  ),
                  children: [
                    for (var ti = 0; ti < d.tasks.length; ti++)
                      TableRow(
                        children: [
                          for (var di = 0; di < d.dayCount; di++)
                            scheduleGridCell(
                              context: context,
                              data: d,
                              taskIndex: ti,
                              dayIndex: di,
                              labelCenterDays: labelCentersByRow[ti],
                              gesturesHandledAbove: false,
                              onTapInCell: () => onCellTap(ti, di),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
