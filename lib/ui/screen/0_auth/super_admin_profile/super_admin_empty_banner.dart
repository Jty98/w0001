import 'package:flutter/material.dart';

class SuperAdminEmptyBanner extends StatelessWidget {
  const SuperAdminEmptyBanner({
    super.key,
    required this.message,
    required this.icon,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cs.surfaceContainerLow.withValues(alpha: 0.55),
      ),
      child: Column(
        children: [
          Icon(icon, size: 26, color: cs.primary.withValues(alpha: 0.45)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}
