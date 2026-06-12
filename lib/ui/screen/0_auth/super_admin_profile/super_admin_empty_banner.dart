import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

class SuperAdminEmptyBanner extends StatelessWidget {
  const SuperAdminEmptyBanner({
    super.key,
    required this.message,
    required this.icon,
    this.compact = false,
  });

  final String message;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vPad = context.rsi(compact ? 10 : 14);
    final iconSize = context.rs(compact ? 20 : 26);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(12),
        vertical: vPad,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
        color: cs.surfaceContainerLow.withValues(alpha: 0.45),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: cs.primary.withValues(alpha: 0.42),
          ),
          SizedBox(width: context.rsi(8)),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
