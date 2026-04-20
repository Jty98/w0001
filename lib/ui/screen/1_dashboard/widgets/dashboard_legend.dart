import 'package:flutter/material.dart';

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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((e) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: e.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: e.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  e.label,
                  style: TextStyle(
                    fontSize: 11,
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

