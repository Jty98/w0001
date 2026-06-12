import 'package:flutter/material.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

class TotalCostCard extends StatelessWidget {
  final String category;
  final String name;
  final int price;
  final int? wcomplete;
  final String? wcompletedAt;

  const TotalCostCard({
    super.key,
    required this.category,
    required this.name,
    required this.price,
    this.wcomplete,
    this.wcompletedAt,
  });

  Widget _pill(
    BuildContext context, {
    required String text,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.rsi(10),
          vertical: context.rsi(6),
        ),
        child: Text(
          text,
          style: tt.labelSmall?.copyWith(
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
    final tt = Theme.of(context).textTheme;
    final isWork = category == 'w';
    final isPaid = isWork && wcomplete == 1;
    final accent = isWork ? cs.primary : cs.tertiary;
    final showNotPaid = isWork && wcomplete == 0;
    final completedAtLabel = wcompletedAt != null && wcompletedAt!.isNotEmpty
        ? formatWorkCostCompletedAt(wcompletedAt!)
        : null;

    if (isPaid) {
      return Card(
        elevation: 0,
        color: cs.primaryContainer.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.rsi(14)),
          side: BorderSide(
            color: cs.primary.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.rsi(14)),
            gradient: LinearGradient(
              colors: [
                cs.primary.withValues(alpha: 0.08),
                cs.primaryContainer.withValues(alpha: 0.02),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(10),
              context.rsi(8),
              context.rsi(10),
              context.rsi(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: context.rs(3),
                  height: context.rs(36),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                SizedBox(width: context.rsi(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.rsi(7),
                              vertical: context.rsi(3),
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius:
                                  BorderRadius.circular(context.rsi(6)),
                            ),
                            child: Text(
                              '지급완료',
                              style: tt.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onPrimary,
                                height: 1,
                              ),
                            ),
                          ),
                          SizedBox(width: context.rsi(6)),
                          _pill(context, text: '인건비', color: accent),
                          SizedBox(width: context.rsi(6)),
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (completedAtLabel != null) ...[
                        SizedBox(height: context.rsi(5)),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: context.rs(12),
                              color: cs.primary.withValues(alpha: 0.85),
                            ),
                            SizedBox(width: context.rsi(4)),
                            Text(
                              completedAtLabel,
                              style: tt.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onPrimaryContainer
                                    .withValues(alpha: 0.85),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: context.rsi(8)),
                Text(
                  getPrice(price: price),
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rsi(14)),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(12),
          context.rsi(10),
          context.rsi(12),
          context.rsi(10),
        ),
        child: Row(
          children: [
            _pill(
              context,
              text: isWork ? '인건비' : '자재비',
              color: accent,
            ),
            SizedBox(width: context.rsi(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isWork && (wcomplete != null))
                    Padding(
                      padding: EdgeInsets.only(top: context.rsi(2)),
                      child: Text(
                        wcomplete == 1 ? '지급완료' : '미지급',
                        style: tt.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              wcomplete == 1 ? cs.onSurfaceVariant : cs.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: context.rsi(10)),
            Text(
              getPrice(price: price),
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: showNotPaid ? cs.error : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
