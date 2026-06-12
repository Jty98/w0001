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
    this.readOnly = false,
    this.onDateHeaderTap,
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
  final bool readOnly;

  /// 관리자: 날짜 헤더 탭 시 (예: 인력 투입 화면으로).
  final void Function(DateTime day)? onDateHeaderTap;

  final void Function(PointerDownEvent e) onStickyPointerDown;
  final void Function(PointerMoveEvent e) onStickyPointerMove;
  final void Function(PointerUpEvent e) onStickyPointerUp;
  final VoidCallback onStickyPointerCancel;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final cellW = ProcessScheduleChartDim.cellW(context);
    final cellH = ProcessScheduleChartDim.cellH(context);
    final tableBody = SizedBox(
      width: d.dayCount * cellW,
      height: d.tasks.length * cellH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Table(
            defaultColumnWidth: FixedColumnWidth(cellW),
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
          if (!readOnly)
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
          height: ProcessScheduleChartDim.headerH(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cornerHeader(context, cs),
              Expanded(
                child: ListView.builder(
                  controller: hHeader,
                  padding: EdgeInsets.zero,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: dates.length,
                  itemBuilder: (ctx, i) => SizedBox(
                    height: ProcessScheduleChartDim.headerH(context),
                    child: dateHeaderCell(
                      context,
                      dates[i],
                      onTap: onDateHeaderTap == null
                          ? null
                          : () => onDateHeaderTap!(dates[i]),
                    ),
                  ),
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
                width: ProcessScheduleChartDim.leftColW(context),
                child: ListView.builder(
                  controller: vLeft,
                  physics: const ClampingScrollPhysics(),
                  itemCount: d.tasks.length,
                  itemExtent: ProcessScheduleChartDim.cellH(context),
                  itemBuilder: (ctx, i) => taskLabelCell(context, d.tasks[i]),
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

double chartContentW(BuildContext context, ProcessScheduleData d) =>
    ProcessScheduleChartDim.leftColW(context) +
    d.dayCount * ProcessScheduleChartDim.cellW(context);

double chartContentH(BuildContext context, ProcessScheduleData d) =>
    ProcessScheduleChartDim.headerH(context) +
    d.tasks.length * ProcessScheduleChartDim.cellH(context);

/// InteractiveViewer 안에 들어가는 고정 크기 표 — 셀 탭만 지원.
class ProcessScheduleOverviewChart extends StatelessWidget {
  const ProcessScheduleOverviewChart({
    super.key,
    required this.cs,
    required this.data,
    required this.dates,
    required this.labelCentersByRow,
    required this.onCellTap,
    this.onDateHeaderTap,
  });

  final ColorScheme cs;
  final ProcessScheduleData data;
  final List<DateTime> dates;
  final List<Set<int>> labelCentersByRow;

  final void Function(int taskIndex, int dayIndex) onCellTap;
  final void Function(DateTime day)? onDateHeaderTap;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final cellW = ProcessScheduleChartDim.cellW(context);
    final cellH = ProcessScheduleChartDim.cellH(context);
    return SizedBox(
      width: chartContentW(context, d),
      height: chartContentH(context, d),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: ProcessScheduleChartDim.headerH(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cornerHeader(context, cs),
                for (var i = 0; i < dates.length; i++)
                  SizedBox(
                    height: ProcessScheduleChartDim.headerH(context),
                    child: dateHeaderCell(
                      context,
                      dates[i],
                      onTap: onDateHeaderTap == null
                          ? null
                          : () => onDateHeaderTap!(dates[i]),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: ProcessScheduleChartDim.leftColW(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in d.tasks)
                      SizedBox(
                        height: cellH,
                        width: ProcessScheduleChartDim.leftColW(context),
                        child: taskLabelCell(context, t),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: d.dayCount * cellW,
                height: d.tasks.length * cellH,
                child: Table(
                  defaultColumnWidth: FixedColumnWidth(cellW),
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
