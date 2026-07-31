import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

enum ProcessScheduleLayout {
  stickyHeaders,
  overview,
}

enum ProcessScheduleScreenOrientation {
  portrait,
  landscape,
}

/// 헤더 고정·한눈에·세로·가로 — 아이콘 4개, spaceBetween.
class ProcessScheduleViewToolbar extends StatelessWidget {
  const ProcessScheduleViewToolbar({
    super.key,
    required this.layout,
    required this.orientation,
    required this.onLayoutChanged,
    required this.onOrientationChanged,
    this.compact = false,
  });

  final ProcessScheduleLayout layout;
  final ProcessScheduleScreenOrientation orientation;
  final ValueChanged<ProcessScheduleLayout> onLayoutChanged;
  final ValueChanged<ProcessScheduleScreenOrientation> onOrientationChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final buttons = [
      _ToolbarIconButton(
        tooltip: '헤더 고정',
        icon: Icons.view_week_outlined,
        selected: layout == ProcessScheduleLayout.stickyHeaders,
        onPressed: () => onLayoutChanged(ProcessScheduleLayout.stickyHeaders),
        colorScheme: cs,
        compact: compact,
      ),
      _ToolbarIconButton(
        tooltip: '한눈에',
        icon: Icons.zoom_out_map_rounded,
        selected: layout == ProcessScheduleLayout.overview,
        onPressed: () => onLayoutChanged(ProcessScheduleLayout.overview),
        colorScheme: cs,
        compact: compact,
      ),
      _ToolbarIconButton(
        tooltip: '세로',
        icon: Icons.stay_current_portrait_rounded,
        selected: orientation == ProcessScheduleScreenOrientation.portrait,
        onPressed: () =>
            onOrientationChanged(ProcessScheduleScreenOrientation.portrait),
        colorScheme: cs,
        compact: compact,
      ),
      _ToolbarIconButton(
        tooltip: '가로',
        icon: Icons.stay_current_landscape_rounded,
        selected: orientation == ProcessScheduleScreenOrientation.landscape,
        onPressed: () =>
            onOrientationChanged(ProcessScheduleScreenOrientation.landscape),
        colorScheme: cs,
        compact: compact,
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 0 : context.rsi(2)),
      child: compact
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0) SizedBox(width: context.rsi(2)),
                  buttons[i],
                ],
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: buttons,
            ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
    required this.colorScheme,
    this.compact = false,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final side = compact ? context.rsi(32) : context.rsi(44);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: compact ? context.rsi(18) : context.rsi(22)),
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        foregroundColor: selected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
        minimumSize: Size(side, side),
        maximumSize: Size(side, side),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
