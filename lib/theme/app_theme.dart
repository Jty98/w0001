import 'package:flutter/material.dart';
import 'package:w0001/theme/app_colors.dart';
import 'package:w0001/theme/app_segmented_button.dart';
import 'package:w0001/theme/app_typography.dart';

/// 앱 라이트/다크 테마 — [AppColors]와 M3 [ColorScheme]을 맞춘다.
abstract final class AppTheme {
  static ThemeData light() {
    // 시드로 primary 계열만 쓰고, 배경·컨테이너는 중립 흰색/그레이로 답답함을 줄인다(M3 surface tint도 끔).
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primaryColor,
      onPrimary: Colors.white,
      secondary: AppColors.accentColor,
      onSecondary: AppColors.textPrimary,
      surface: AppColors.backgroundColor,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF5F5F5),
      surfaceContainer: const Color(0xFFF0F0F0),
      surfaceContainerHigh: const Color(0xFFE8E8E8),
      surfaceContainerHighest: const Color(0xFFE0E0E0),
      outlineVariant: const Color(0xFFE0E0E0),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: 'SCDream',
    );

    final textTheme = AppTypography.light(base.textTheme, colorScheme.onSurface);

    return base.copyWith(
      textTheme: textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        toolbarHeight: 64, // 논리 dp — 전역 TextScaler와 별도
        titleTextStyle: textTheme.titleLarge,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            side: BorderSide(width: 2, color: colorScheme.outline),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontFamily: 'SCDream',
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
      segmentedButtonTheme: AppSegmentedButton.themeData(colorScheme),
    );
  }

  static ThemeData dark() {
    // 다크 모드용 ColorScheme — 가독성 개선을 위해 더 밝은 텍스트 색상 사용
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primaryColor,
      onPrimary: Colors.white,
      secondary: AppColors.accentColor,
      onSecondary: Colors.white,
      surface: const Color(0xFF1C1C1E), // 약간 더 밝은 배경
      onSurface: const Color(0xFFEEEEEE), // 더 밝은 텍스트
      onSurfaceVariant: const Color(0xFFC8C8C8), // 더 밝은 보조 텍스트
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: const Color(0xFF0F0F0F),
      surfaceContainerLow: const Color(0xFF212121),
      surfaceContainer: const Color(0xFF2A2A2A),
      surfaceContainerHigh: const Color(0xFF333333),
      surfaceContainerHighest: const Color(0xFF3D3D3D),
      outlineVariant: const Color(0xFF484848),
      outline: const Color(0xFF606060),
      shadow: Colors.black,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: 'SCDream',
    );

    final textTheme = AppTypography.light(base.textTheme, colorScheme.onSurface);

    return base.copyWith(
      textTheme: textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        toolbarHeight: 64,
        titleTextStyle: textTheme.titleLarge,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            side: BorderSide(width: 2, color: colorScheme.outline),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontFamily: 'SCDream',
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
      segmentedButtonTheme: AppSegmentedButton.themeData(colorScheme),
    );
  }
}
