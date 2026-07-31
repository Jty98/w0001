import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 인력·회원 상세 공통 정보 행.
class WorkerProfileInfoRow extends StatelessWidget {
  const WorkerProfileInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.icon,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rsi(5)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: context.rs(18), color: cs.primary),
            SizedBox(width: context.rsi(8)),
          ],
          SizedBox(
            width: context.rsi(icon != null ? 64 : 72),
            child: Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
