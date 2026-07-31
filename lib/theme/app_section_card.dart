import 'package:flutter/material.dart';
import 'package:w0001/theme/app_elevation.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 인기 서비스 UI(토스·노션·iOS 그룹드 리스트) 스타일 섹션 카드.
abstract final class AppSectionCardStyles {
  static const double radius = 16;

  static BorderRadius borderRadius(BuildContext context) =>
      BorderRadius.circular(context.rs(radius));

  static BoxDecoration cardDecoration(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppElevation.sectionCard(
      context: context,
      backgroundColor: cs.appCardSurface,
      borderRadius: borderRadius(context),
      borderColor: cs.appBorder,
      shadowIntensity: 1.3,
    );
  }

  static BoxDecoration iconBadgeDecoration(
      BuildContext context, ColorScheme cs) {
    return BoxDecoration(
      color: cs.appIconBadge,
      borderRadius: BorderRadius.circular(context.rs(12)),
    );
  }
}

/// 앱 전역 섹션 카드 — 대시보드·일정·설정 등에서 공통 사용.
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.contentPadding,
    this.denseHeader = false,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? contentPadding;
  final bool denseHeader;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = iconColor ?? cs.primary;
    final radius = AppSectionCardStyles.borderRadius(context);
    final resolvedContentPadding = contentPadding ??
        EdgeInsets.fromLTRB(
          context.rsi(16),
          context.rsi(14),
          context.rsi(16),
          context.rsi(16),
        );

    return DecoratedBox(
      decoration: AppSectionCardStyles.cardDecoration(context),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.rsi(16),
                context.rsi(denseHeader ? 12 : 14),
                context.rsi(16),
                context.rsi(denseHeader ? 10 : 12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: context.rs(40),
                    height: context.rs(40),
                    alignment: Alignment.center,
                    decoration: AppSectionCardStyles.iconBadgeDecoration(
                      context,
                      cs,
                    ),
                    child: Icon(icon, color: accent, size: context.rs(20)),
                  ),
                  SizedBox(width: context.rsi(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: cs.onSurface,
                            height: 1.25,
                          ),
                        ),
                        if (subtitle != null &&
                            subtitle!.trim().isNotEmpty) ...[
                          SizedBox(height: context.rsi(2)),
                          Text(
                            subtitle!,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: cs.appDivider,
            ),
            Padding(
              padding: resolvedContentPadding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// 대시보드 상단 인사 — 타이포 중심 미니멀 배너.
class AppWelcomeBanner extends StatelessWidget {
  const AppWelcomeBanner({
    super.key,
    required this.greeting,
    this.subGreeting,
    this.icon = Icons.waving_hand_rounded,
  });

  final String greeting;
  final String? subGreeting;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: AppSectionCardStyles.cardDecoration(context),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(16),
          context.rsi(14),
          context.rsi(16),
          context.rsi(14),
        ),
        child: Row(
          children: [
            Container(
              width: context.rs(44),
              height: context.rs(44),
              alignment: Alignment.center,
              decoration: AppSectionCardStyles.iconBadgeDecoration(
                context,
                cs,
              ),
              child: Icon(icon, color: cs.primary, size: context.rs(22)),
            ),
            SizedBox(width: context.rsi(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      height: 1.25,
                    ),
                  ),
                  if (subGreeting != null &&
                      subGreeting!.trim().isNotEmpty) ...[
                    SizedBox(height: context.rsi(2)),
                    Text(
                      subGreeting!,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 헤더 없는 카드 — 설정 리스트·폼 그룹·중첩 패널.
class AppInsetCard extends StatelessWidget {
  const AppInsetCard({
    super.key,
    required this.child,
    this.padding,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final radius = AppSectionCardStyles.borderRadius(context);
    return DecoratedBox(
      decoration: AppSectionCardStyles.cardDecoration(context),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: clipBehavior,
        child:
            padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );
  }
}

/// 섹션 위 제목 — 설정·폼 화면 그룹 라벨.
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle(
    this.text, {
    super.key,
    this.padding,
  });

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: padding ??
          EdgeInsets.only(
            left: context.rsi(4),
            bottom: context.rsi(8),
          ),
      child: Text(
        text,
        style: tt.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.15,
          color: cs.onSurface,
        ),
      ),
    );
  }
}

/// 리스트·폼 행 사이 구분선.
class AppInsetDivider extends StatelessWidget {
  const AppInsetDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      thickness: 1,
      color: cs.appDivider,
    );
  }
}

/// 중첩 항목·리스트 타일 — 그림자 없이 테두리만.
class AppInsetTile extends StatelessWidget {
  const AppInsetTile({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(context.rs(12));
    return DecoratedBox(
      decoration: AppElevation.insetTile(
        context: context,
        backgroundColor: backgroundColor ?? cs.appInsetFill,
        borderRadius: radius,
      ),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );
  }
}
