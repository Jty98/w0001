import 'package:flutter/material.dart';
import 'package:w0001/theme/app_colors.dart';
import 'package:w0001/theme/app_input_styles.dart';
import 'package:w0001/theme/app_segmented_button.dart';
import 'package:w0001/theme/app_typography.dart';

/// 앱 라이트/다크 테마 — [AppColors]와 M3 [ColorScheme]을 맞춘다.
abstract final class AppTheme {
  static const double _buttonRadius = 12;

  static RoundedRectangleBorder get _buttonShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonRadius),
      );

  static ButtonStyle get _buttonStyle => ButtonStyle(
        shape: WidgetStatePropertyAll(_buttonShape),
      );

  static ThemeData light() {
    // 네이비(primary)·그레이(텍스트/서피스) 중심. 스카이 블루는 tertiary로만 두어 M3 자동 틴트를 최소화.
    // 이전: seedColor=오렌지, secondary=베이지, surface=#FAFAFA
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primaryColor,
      onPrimary: Colors.white,
      primaryContainer: AppColors.iconBadgeFill,
      onPrimaryContainer: AppColors.primaryColor,
      secondary: AppColors.textSecondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.surfaceMuted,
      onSecondaryContainer: AppColors.textPrimary,
      tertiary: AppColors.accentColor,
      onTertiary: AppColors.textPrimary,
      tertiaryContainer: const Color(0xFFEAF7FE),
      onTertiaryContainer: AppColors.textPrimary,
      surface: AppColors.cardBackground,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.borderColor,
      surfaceTint: Colors.transparent,
      shadow: const Color(0x1A1A1A2E),
      surfaceContainerLowest: AppColors.backgroundColor,
      surfaceContainerLow: const Color(0xFFFAFAFA),
      surfaceContainer: const Color(0xFFF5F5F5),
      surfaceContainerHigh: const Color(0xFFE5E7EB),
      surfaceContainerHighest: const Color(0xFFD1D5DB),
      outlineVariant: AppColors.borderColor,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: AppTypography.fontFamily,
    );

    final textTheme =
        AppTypography.light(base.textTheme, colorScheme.onSurface);
    final appliedTextTheme = textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
      fontFamily: AppTypography.fontFamily,
    );

    return base.copyWith(
      textTheme: appliedTextTheme,
      primaryTextTheme: appliedTextTheme,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      primaryIconTheme: IconThemeData(color: colorScheme.onSurface),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shadowColor: colorScheme.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        toolbarHeight: 64, // 논리 dp — 전역 TextScaler와 별도
        titleTextStyle: appliedTextTheme.titleLarge,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        textStyle: WidgetStatePropertyAll(
          TextStyle(
            inherit: false,
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            textBaseline: TextBaseline.alphabetic,
            fontFeatures: AppInputStyles.inputFontFeatures,
          ),
        ),
        hintStyle: WidgetStatePropertyAll(
          TextStyle(
            inherit: false,
            color: colorScheme.onSurfaceVariant,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            textBaseline: TextBaseline.alphabetic,
          ),
        ),
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
      filledButtonTheme: FilledButtonThemeData(style: _buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonStyle),
      textButtonTheme: TextButtonThemeData(style: _buttonStyle),
      iconButtonTheme: IconButtonThemeData(style: _buttonStyle),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: AppInputStyles.inputDecorationTheme(colorScheme),
      textSelectionTheme: AppInputStyles.textSelectionTheme(colorScheme),
      segmentedButtonTheme: AppSegmentedButton.themeData(colorScheme),
    );
  }

  static ThemeData dark() {
    const onSurface = Color(0xFFEEEEEC);
    const onSurfaceVariant = Color(0xFFAEAEAC);
    const cardSurface = Color(0xFF323230);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF4A7AB5),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF243B55),
      onPrimaryContainer: const Color(0xFFB8D4F0),
      secondary: onSurfaceVariant,
      onSecondary: onSurface,
      secondaryContainer: const Color(0xFF3A3A38),
      onSecondaryContainer: onSurface,
      tertiary: AppColors.accentColor,
      onTertiary: const Color(0xFF1A1A1A),
      tertiaryContainer: const Color(0xFF2A4A5E),
      onTertiaryContainer: const Color(0xFFC8ECFC),
      surface: cardSurface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      surfaceTint: Colors.transparent,
      shadow: Colors.black,
      surfaceContainerLowest: const Color(0xFF1E1E1C),
      surfaceContainerLow: const Color(0xFF2A2A28),
      surfaceContainer: const Color(0xFF3A3A38),
      surfaceContainerHigh: const Color(0xFF444442),
      surfaceContainerHighest: const Color(0xFF4E4E4C),
      outlineVariant: const Color(0xFF4E4E4C),
      outline: const Color(0xFF6E6E6C),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      fontFamily: AppTypography.fontFamily,
    );

    final textTheme =
        AppTypography.light(base.textTheme, colorScheme.onSurface);
    final appliedTextTheme = textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
      fontFamily: AppTypography.fontFamily,
    );

    return base.copyWith(
      textTheme: appliedTextTheme,
      primaryTextTheme: appliedTextTheme,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      primaryIconTheme: IconThemeData(color: colorScheme.onSurface),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shadowColor: colorScheme.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        toolbarHeight: 64,
        titleTextStyle: appliedTextTheme.titleLarge,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        textStyle: WidgetStatePropertyAll(
          TextStyle(
            inherit: false,
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            textBaseline: TextBaseline.alphabetic,
            fontFeatures: AppInputStyles.inputFontFeatures,
          ),
        ),
        hintStyle: WidgetStatePropertyAll(
          TextStyle(
            inherit: false,
            color: colorScheme.onSurfaceVariant,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            textBaseline: TextBaseline.alphabetic,
          ),
        ),
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
      filledButtonTheme: FilledButtonThemeData(style: _buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonStyle),
      textButtonTheme: TextButtonThemeData(style: _buttonStyle),
      iconButtonTheme: IconButtonThemeData(style: _buttonStyle),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: AppInputStyles.inputDecorationTheme(colorScheme),
      textSelectionTheme: AppInputStyles.textSelectionTheme(colorScheme),
      segmentedButtonTheme: AppSegmentedButton.themeData(colorScheme),
    );
  }
}
