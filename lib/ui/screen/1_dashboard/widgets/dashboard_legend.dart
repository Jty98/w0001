import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

class DashboardLegendItem {
  final String label;
  final Color color;
  const DashboardLegendItem({required this.label, required this.color});
}

class DashboardLegend extends StatelessWidget {
  const DashboardLegend({super.key, required this.items});
  final List<DashboardLegendItem> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Wrap(
      spacing: context.rsi(8),
      runSpacing: context.rsi(8),
      children: items.map((e) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: e.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.rsi(10),
              vertical: context.rsi(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: context.rs(8),
                  height: context.rs(8),
                  decoration: BoxDecoration(
                    color: e.color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: context.rsi(8)),
                Text(
                  e.label,
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
