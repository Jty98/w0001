import 'package:flutter/material.dart';
import 'package:w0001/theme/app_elevation.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/util/responsive_layout.dart';

class DashboardSummaryCard extends StatelessWidget {
  const DashboardSummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.color,
    required this.icon,
    this.valueCaption,
    this.valueSecondary,
    this.valueSecondaryCaption,
    this.onTap,
  });

  final String title;
  final String value;

  /// 하위 호환 — 배경 틴트에는 사용하지 않음.
  final Color? color;
  final IconData icon;

  /// 주 값 위 작은 라벨 (예: `진행`).
  final String? valueCaption;

  /// 보조 값 (이익률·완료 건수 등).
  final String? valueSecondary;

  /// 보조 값 위 작은 라벨 (예: `완료`, `이익률`).
  final String? valueSecondaryCaption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final captionStyle = tt.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: cs.onSurfaceVariant.withValues(alpha: 0.88),
      height: 1.0,
      fontSize: (tt.labelSmall?.fontSize ?? 11) * 0.92,
    );
    final valueStyle = tt.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface,
      height: 1.05,
      fontSize: (tt.titleSmall?.fontSize ?? 14) * 0.88,
      letterSpacing: -0.2,
    );
    final secondaryValueStyle = valueStyle?.copyWith(
      fontSize: (valueStyle.fontSize ?? 14) * 0.94,
    );

    final child = SizedBox(
      height: context.rs(72),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.rsi(10),
          vertical: context.rsi(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: context.rsi(14), color: cs.primary),
                SizedBox(width: context.rsi(5)),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      height: 1.0,
                      fontSize: (tt.labelSmall?.fontSize ?? 11) * 0.9,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: context.rsi(15),
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
              ],
            ),
            const Spacer(),
            SizedBox(
              height: context.rs(30),
              child: valueSecondary == null
                  ? _buildSingleValue(
                      context,
                      caption: valueCaption,
                      value: value,
                      captionStyle: captionStyle,
                      valueStyle: valueStyle,
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildSingleValue(
                            context,
                            caption: valueCaption,
                            value: value,
                            captionStyle: captionStyle,
                            valueStyle: valueStyle,
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                        SizedBox(width: context.rsi(4)),
                        Expanded(
                          child: _buildSingleValue(
                            context,
                            caption: valueSecondaryCaption,
                            value: valueSecondary!,
                            captionStyle: captionStyle,
                            valueStyle: secondaryValueStyle ?? valueStyle,
                            alignment: Alignment.centerRight,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );

    final radius = BorderRadius.circular(context.rs(10));
    final box = DecoratedBox(
      decoration: AppElevation.insetTile(
        context: context,
        backgroundColor: cs.appInsetFill,
        borderRadius: radius,
      ),
      child: onTap == null
          ? child
          : Material(
              type: MaterialType.transparency,
              borderRadius: radius,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: child,
              ),
            ),
    );
    return box;
  }

  Widget _buildSingleValue(
    BuildContext context, {
    required String? caption,
    required String value,
    required TextStyle? captionStyle,
    required TextStyle? valueStyle,
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment == Alignment.centerRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (caption != null && caption.isNotEmpty) ...[
          Text(caption, maxLines: 1, style: captionStyle),
          SizedBox(height: context.rsi(2)),
        ],
        SizedBox(
          height: context.rs(15),
          child: Align(
            alignment: alignment,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: alignment,
              child: Text(
                value,
                maxLines: 1,
                style: valueStyle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
