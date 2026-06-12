import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 스크롤·폼 화면용 — 좌우 패딩·최대 너비·태블릿 중앙 정렬.
class ResponsivePageShell extends StatelessWidget {
  const ResponsivePageShell({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
    this.center = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? ResponsiveLayout.pagePadding(context);
    final limit = maxWidth ?? ResponsiveLayout.contentMaxWidth(context);

    Widget body = Padding(padding: pad, child: child);
    body = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: limit),
      child: body,
    );
    if (center && ResponsiveLayout.isWide(context)) {
      body = Align(alignment: Alignment.topCenter, child: body);
    }
    return body;
  }
}
