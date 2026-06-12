import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

class DashboardSummaryCard extends StatelessWidget {
  const DashboardSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.subtitle,
    this.valueSecondary,
    this.onTap,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final String? subtitle;

  /// 금액 행 오른쪽 (이익률 등). 한 줄 안에서 금액은 말줄임으로 잘립니다.
  final String? valueSecondary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final child = Padding(
      padding: ResponsiveLayout.only(
        context,
        left: 12,
        top: 10,
        right: 12,
        bottom: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: context.rsi(14), color: cs.onSurfaceVariant),
              rsH(context, 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurfaceVariant,
                        height: 1.0,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                          height: 1.15,
                        ),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: context.rsi(20),
                  color: cs.onSurfaceVariant,
                ),
            ],
          ),
          rsV(context, 6),
          SizedBox(
            height: context.rs(22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: valueSecondary == null
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              value,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: cs.onSurface,
                                height: 1.0,
                              ),
                            ),
                          )
                        : Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: cs.onSurface,
                              height: 1.0,
                            ),
                          ),
                  ),
                ),
                if (valueSecondary != null) ...[
                  rsH(context, 6),
                  Text(
                    valueSecondary!,
                    maxLines: 1,
                    style: tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      height: 1.0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final radius = context.rs(14);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: onTap == null
          ? child
          : Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(radius),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: child,
              ),
            ),
    );
    return box;
  }
}
