import 'package:flutter/material.dart';
import 'package:w0001/theme/app_typography.dart';
import 'package:w0001/util/responsive_layout.dart';

/// TextField·TextFormField·Quill 공통 — 실기기 IME에서 글자가 투명해지는 문제 방지.
///
/// 입력 본문만 [TextStyle.inherit] false + 시스템 글꼴. 라벨·힌트는 SCDream 유지.
abstract final class AppInputStyles {
  static const List<FontFeature> inputFontFeatures = [
    FontFeature.disable('calt'),
  ];

  static bool _colorIsInvisible(Color? color) {
    if (color == null) return true;
    return color.alpha == 0;
  }

  /// 입력 본문 — SCDream 상속 차단, 시스템 글꼴 + [onSurface] 색.
  static TextStyle fieldText(
    BuildContext context, {
    TextStyle? base,
    double designFontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    double? height,
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final resolvedColor = color ?? cs.onSurface;
    final seed = base;
    final resolvedSize = seed?.fontSize ?? context.rsi(designFontSize);
    final resolvedWeight = seed?.fontWeight ?? fontWeight;
    final resolvedHeight = height ?? seed?.height;

    return TextStyle(
      inherit: false,
      color: resolvedColor,
      fontSize: resolvedSize,
      fontWeight: resolvedWeight,
      height: resolvedHeight,
      letterSpacing: seed?.letterSpacing,
      wordSpacing: seed?.wordSpacing,
      textBaseline: seed?.textBaseline ?? TextBaseline.alphabetic,
      locale: seed?.locale,
      fontFeatures: inputFontFeatures,
      decoration: seed?.decoration ?? TextDecoration.none,
      decorationColor: seed?.decorationColor,
    );
  }

  /// Quill [TextSpan] — 투명·미지정 색을 [onSurface]로 치환.
  static TextStyle visibleTextStyle(
    BuildContext context,
    TextStyle? style, {
    Color? fallbackColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    final color = fallbackColor ?? cs.onSurface;
    final seed = style;
    if (seed == null || _colorIsInvisible(seed.color)) {
      return fieldText(
        context,
        base: seed,
        designFontSize: seed?.fontSize != null
            ? seed!.fontSize! / context.deviceTextScale
            : 16,
        fontWeight: seed?.fontWeight ?? FontWeight.w500,
        height: seed?.height ?? 1.45,
        color: color,
      );
    }
    return fieldText(
      context,
      base: seed,
      designFontSize:
          seed.fontSize != null ? seed.fontSize! / context.deviceTextScale : 16,
      fontWeight: seed.fontWeight ?? FontWeight.w500,
      height: seed.height ?? 1.45,
      color: seed.color,
    );
  }

  static InputDecorationTheme inputDecorationTheme(
    ColorScheme colorScheme,
  ) {
    TextStyle labelLike(Color c, {FontWeight weight = FontWeight.w500}) {
      return TextStyle(
        fontFamily: AppTypography.fontFamily,
        color: c,
        fontWeight: weight,
        fontFeatures: inputFontFeatures,
      );
    }

    return InputDecorationTheme(
      hintStyle: labelLike(colorScheme.onSurfaceVariant),
      labelStyle:
          labelLike(colorScheme.onSurfaceVariant, weight: FontWeight.w600),
      floatingLabelStyle:
          labelLike(colorScheme.onSurfaceVariant, weight: FontWeight.w600),
      errorStyle: labelLike(colorScheme.error, weight: FontWeight.w600),
    );
  }

  static TextSelectionThemeData textSelectionTheme(ColorScheme colorScheme) {
    return TextSelectionThemeData(
      cursorColor: colorScheme.primary,
      selectionColor: colorScheme.primary.withValues(alpha: 0.28),
      selectionHandleColor: colorScheme.primary,
    );
  }
}
