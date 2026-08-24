import 'package:flutter/material.dart';
import 'package:w0001/data/model/work_unit_preset.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 금액 수정 시 공수(시간 단위)를 고르는 칩 행.
class WorkUnitChipSelector extends StatelessWidget {
  const WorkUnitChipSelector({
    super.key,
    required this.units,
    required this.selectedId,
    required this.onSelected,
    this.enabled = true,
    this.dense = false,
  });

  final List<WorkUnitPreset> units;
  final String? selectedId;
  final ValueChanged<WorkUnitPreset> onSelected;
  final bool enabled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final gap = dense ? context.rsi(6) : context.rsi(8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '공수 선택',
          style: tt.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        SizedBox(height: context.rsi(dense ? 6 : 8)),
        Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final unit in units)
              _WorkUnitChip(
                unit: unit,
                selected: selectedId == unit.id,
                enabled: enabled,
                dense: dense,
                onTap: () => onSelected(unit),
              ),
          ],
        ),
      ],
    );
  }
}

class _WorkUnitChip extends StatelessWidget {
  const _WorkUnitChip({
    required this.unit,
    required this.selected,
    required this.enabled,
    required this.dense,
    required this.onTap,
  });

  final WorkUnitPreset unit;
  final bool selected;
  final bool enabled;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(context.rsi(dense ? 10 : 12));

    final bg = !enabled
        ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
        : selected
            ? cs.primary
            : cs.surfaceContainerHighest.withValues(alpha: 0.55);
    final fg = !enabled
        ? cs.onSurfaceVariant.withValues(alpha: 0.55)
        : selected
            ? cs.onPrimary
            : cs.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(dense ? 10 : 12),
            vertical: context.rsi(dense ? 8 : 10),
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(
              color: selected && enabled
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.55),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                unit.label,
                style: (dense ? tt.labelMedium : tt.labelLarge)?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
              SizedBox(height: context.rsi(2)),
              Text(
                unit.adjustSummary,
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected && enabled
                      ? cs.onPrimary.withValues(alpha: 0.85)
                      : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
