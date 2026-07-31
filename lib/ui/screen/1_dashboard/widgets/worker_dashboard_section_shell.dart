import 'package:flutter/material.dart';
import 'package:w0001/theme/app_section_card.dart';

/// 작업자 대시보드 — [AppSectionCard] 래퍼.
class WorkerDashboardSectionShell extends StatelessWidget {
  const WorkerDashboardSectionShell({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.iconColor,
    this.headerTint,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final Color? iconColor;
  final Color? headerTint;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      iconColor: iconColor,
      child: child,
    );
  }
}

/// 상단 인사말 배너.
class WorkerDashboardWelcomeBanner extends StatelessWidget {
  const WorkerDashboardWelcomeBanner({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return AppWelcomeBanner(
      greeting: '$name님, 안녕하세요',
      subGreeting: '오늘도 안전한 하루 되세요!',
    );
  }
}
