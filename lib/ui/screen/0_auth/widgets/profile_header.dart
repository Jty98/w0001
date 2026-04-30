import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.uname});

  final String uname;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final initial =
        uname.isNotEmpty ? String.fromCharCodes(uname.runes.take(1)) : '?';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: cs.primaryContainer,
          child: Text(
            initial,
            style: tt.titleLarge?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            uname,
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
