import 'package:flutter/material.dart';
import 'package:w0001/domain/process_schedule/process_schedule_editor.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/domain/process_schedule/process_schedule_palette.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/app_text_field.dart';

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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.labelSmall?.copyWith(
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
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            scheduleDateHeaderDayLine(day),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: context.rsi(11),
              color: isWeekend
                  ? (day.weekday == DateTime.sunday ? cs.error : cs.primary)
                  : cs.onSurface,
              height: 1.05,
            ),
          ),
          Text(
            scheduleDateHeaderWeekdayLine(day),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: context.rsi(10),
              color: isWeekend
                  ? (day.weekday == DateTime.sunday ? cs.error : cs.primary)
                  : cs.onSurfaceVariant,
              height: 1.05,
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
  VoidCallback? onTap,
  VoidCallback? onLongPress,
}) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final bar = Color(ProcessSchedulePalette.argbAt(row.paletteIndex));
  final displayName = row.name.trim().isEmpty ? '공정 이름' : row.name;
  final nameStyle = row.name.trim().isEmpty
      ? tt.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.primary.withValues(alpha: 0.85),
          height: 1.1,
          fontStyle: FontStyle.italic,
        )
      : tt.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: cs.onSurface,
          height: 1.1,
        );

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
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: nameStyle,
            ),
          ),
        ),
      ],
    ),
  );

  if (onTap == null && onLongPress == null) {
    return content;
  }

  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: content,
    ),
  );
}

/// 구분 열 — 탭하면 이름을 바로 입력한다.
class EditableTaskLabelCell extends StatefulWidget {
  const EditableTaskLabelCell({
    super.key,
    required this.row,
    required this.readOnly,
    required this.onNameCommitted,
  });

  final ProcessScheduleTask row;
  final bool readOnly;
  final ValueChanged<String> onNameCommitted;

  @override
  State<EditableTaskLabelCell> createState() => _EditableTaskLabelCellState();
}

class _EditableTaskLabelCellState extends State<EditableTaskLabelCell> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.row.name);
    _focusNode = FocusNode()..addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(EditableTaskLabelCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.row.name != widget.row.name) {
      _controller.text = widget.row.name;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (!_focusNode.hasFocus && _editing) {
      _commit();
    }
  }

  void _commit() {
    if (!mounted) return;
    setState(() => _editing = false);
    widget.onNameCommitted(_controller.text.trim());
  }

  void _startEdit() {
    if (widget.readOnly) return;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      final cs = Theme.of(context).colorScheme;
      final bar = Color(ProcessSchedulePalette.argbAt(widget.row.paletteIndex));
      return DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withValues(alpha: 0.95),
          border: Border(
            right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
            bottom:
                BorderSide(color: cs.outlineVariant.withValues(alpha: 0.25)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: context.rs(5),
              color: bar,
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rsi(6),
                  vertical: context.rsi(4),
                ),
                child: AppTextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    hintText: '공정 이름',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _commit(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return taskLabelCell(
      context,
      widget.row,
      onTap: widget.readOnly ? null : _startEdit,
    );
  }
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  fontSize: context.rsi(10),
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
