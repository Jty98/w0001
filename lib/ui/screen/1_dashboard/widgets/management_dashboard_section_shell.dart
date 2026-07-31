import 'package:flutter/material.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 관리자 상황판 — [AppSectionCard] 래퍼.
class ManagementDashboardSectionShell extends StatelessWidget {
  const ManagementDashboardSectionShell({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.denseHeader = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final bool denseHeader;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      denseHeader: denseHeader,
      contentPadding: EdgeInsets.fromLTRB(
        context.rsi(14),
        context.rsi(12),
        context.rsi(14),
        context.rsi(14),
      ),
      child: child,
    );
  }
}
