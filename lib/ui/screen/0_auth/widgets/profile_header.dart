import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.uname,
    this.compact = false,
  });

  final String uname;

  /// 워커 등 한 화면에 맞출 때 아바타·글자 크기 축소.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final initial =
        uname.isNotEmpty ? String.fromCharCodes(uname.runes.take(1)) : '?';

    final nameStyle = compact
        ? tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
          )
        : tt.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: compact ? 22 : 30,
          backgroundColor: cs.primaryContainer,
          child: Text(
            initial,
            style: (compact ? tt.titleMedium : tt.titleLarge)?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(width: compact ? 12 : 16),
        Expanded(
          child: Text(
            uname,
            style: nameStyle,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
