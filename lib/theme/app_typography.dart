import 'package:flutter/material.dart';

/// 디자인 기준(390dp shortest) 타이포. 실제 렌더 크기는 [ResponsiveLayout.appTextScaler]가 조정한다.
abstract final class AppTypography {
  static const String fontFamily = 'SCDream';

  static TextTheme light(TextTheme base, Color onSurface) {
    TextStyle s(
      TextStyle? from,
      double size,
      FontWeight weight, {
      double? height,
      Color? color,
    }) {
      return (from ?? const TextStyle()).copyWith(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color ?? onSurface,
      );
    }

    return base.copyWith(
      displaySmall: s(base.displaySmall, 36, FontWeight.w700, height: 1.15),
      headlineMedium: s(base.headlineMedium, 28, FontWeight.w700, height: 1.2),
      headlineSmall: s(base.headlineSmall, 24, FontWeight.w700, height: 1.2),
      titleLarge: s(base.titleLarge, 22, FontWeight.w700, height: 1.25),
      titleMedium: s(base.titleMedium, 16, FontWeight.w600, height: 1.3),
      titleSmall: s(base.titleSmall, 14, FontWeight.w700, height: 1.3),
      bodyLarge: s(base.bodyLarge, 16, FontWeight.w500, height: 1.35),
      bodyMedium: s(base.bodyMedium, 14, FontWeight.w400, height: 1.4),
      bodySmall: s(base.bodySmall, 12, FontWeight.w400, height: 1.35),
      labelLarge: s(base.labelLarge, 14, FontWeight.w600, height: 1.2),
      labelMedium: s(base.labelMedium, 12, FontWeight.w500, height: 1.2),
      labelSmall: s(base.labelSmall, 11, FontWeight.w500, height: 1.15),
    );
  }
}
