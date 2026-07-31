import 'package:flutter/material.dart';
import 'package:w0001/theme/app_theme_colors.dart';

/// 카드·섹션 구분용 그림자·테두리.
abstract final class AppElevation {
  static List<BoxShadow> cardShadow(
    BuildContext context, {
    double intensity = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.42 * intensity),
          blurRadius: 22,
          offset: const Offset(0, 8),
          spreadRadius: -3,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22 * intensity),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF0F172A).withValues(alpha: 0.05 * intensity),
        blurRadius: 28,
        offset: const Offset(0, 10),
        spreadRadius: -6,
      ),
      BoxShadow(
        color: const Color(0xFF0F172A).withValues(alpha: 0.11 * intensity),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static BoxDecoration sectionCard({
    required BuildContext context,
    required Color backgroundColor,
    required BorderRadius borderRadius,
    Color? borderColor,
    double shadowIntensity = 1,
  }) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: borderRadius,
      border: Border.all(
        color: borderColor ?? cs.appBorder,
        width: 1,
      ),
      boxShadow: cardShadow(context, intensity: shadowIntensity),
    );
  }

  /// 리스트 행·중첩 카드 — 그림자 없이 옅은 테두리만 (외곽 섹션과 대비).
  static BoxDecoration insetTile({
    required BuildContext context,
    required Color backgroundColor,
    required BorderRadius borderRadius,
    Color? borderColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: borderRadius,
      border: Border.all(
        color: borderColor ?? cs.appBorder.withValues(alpha: 0.5),
        width: 1,
      ),
    );
  }
}
