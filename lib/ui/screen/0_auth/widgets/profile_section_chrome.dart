import 'package:flutter/material.dart';
import 'package:w0001/theme/app_section_card.dart';

/// 프로필·설정 화면 섹션 제목 — [AppSectionTitle] 별칭.
class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => AppSectionTitle(text);
}

/// 프로필·설정 화면 그룹 패널 — [AppInsetCard] 별칭.
class ProfileInsetPanel extends StatelessWidget {
  const ProfileInsetPanel({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return AppInsetCard(
      padding: padding,
      clipBehavior: Clip.none,
      child: child,
    );
  }
}
