import 'package:flutter/material.dart';

enum ProcessScheduleLayout {
  stickyHeaders,
  overview,
}

/// 둥근 사각 형태의 레이아웃 전환 컨트롤.
class ProcessScheduleLayoutSegment extends StatelessWidget {
  const ProcessScheduleLayoutSegment({
    super.key,
    required this.layout,
    required this.radius,
    required this.onChanged,
  });

  final ProcessScheduleLayout layout;
  final double radius;
  final ValueChanged<ProcessScheduleLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
    );
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: border,
      clipBehavior: Clip.antiAlias,
      child: SegmentedButton<ProcessScheduleLayout>(
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: WidgetStateProperty.all(BorderSide.none),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius - 3),
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return cs.primaryContainer;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return cs.onPrimaryContainer;
            }
            return cs.onSurfaceVariant;
          }),
        ),
        segments: const [
          ButtonSegment(
            value: ProcessScheduleLayout.stickyHeaders,
            label: Text('헤더 고정'),
            icon: Icon(Icons.view_week_outlined, size: 18),
          ),
          ButtonSegment(
            value: ProcessScheduleLayout.overview,
            label: Text('한눈에'),
            icon: Icon(Icons.zoom_out_map_rounded, size: 18),
          ),
        ],
        selected: {layout},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}
