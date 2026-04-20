import 'package:flutter/material.dart';

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
    final child = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
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
                        style: TextStyle(
                          fontSize: 9,
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
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 22,
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
                              style: TextStyle(
                                fontSize: 15,
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
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: cs.onSurface,
                              height: 1.0,
                            ),
                          ),
                  ),
                ),
                if (valueSecondary != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    valueSecondary!,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
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

    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: onTap == null
          ? child
          : Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: child,
              ),
            ),
    );
    return box;
  }
}
