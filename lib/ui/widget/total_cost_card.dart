import 'package:flutter/material.dart';
import 'package:w0001/util/funtions.dart';

class TotalCostCard extends StatelessWidget {
  final String category;
  final String name;
  final int price;
  final int? wcomplete;
  const TotalCostCard({
    super.key,
    required this.category,
    required this.name,
    required this.price,
    this.wcomplete,
  });

  Widget _pill(
    BuildContext context, {
    required String text,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWork = category == 'w';
    final accent = isWork ? (Colors.blue[700] ?? cs.primary) : (Colors.green[700] ?? cs.tertiary);
    final showNotPaid = isWork && wcomplete == 0;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            _pill(
              context,
              text: isWork ? '인건비' : '자재비',
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isWork && (wcomplete != null))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        wcomplete == 1 ? '지급완료' : '미지급',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: wcomplete == 1 ? cs.onSurfaceVariant : Colors.red[700],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              getPrice(price: price),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: showNotPaid ? Colors.red[700] : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
