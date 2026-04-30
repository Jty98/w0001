import 'package:flutter/material.dart';

/// 프로필 본문에서 블록 구분용 짧은 제목 줄.
class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 3,
          height: 15,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: cs.primary.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.15,
          ),
        ),
      ],
    );
  }
}

/// 낮은 높이·얇은 테두리 안에 섹션 본문을 묶음.
class ProfileInsetPanel extends StatelessWidget {
  const ProfileInsetPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(1),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
