import 'package:flutter/material.dart';

class ProfileRowDivider extends StatelessWidget {
  const ProfileRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      thickness: 1,
      color: cs.outlineVariant.withValues(alpha: 0.4),
    );
  }
}
