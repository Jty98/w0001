import 'package:flutter/material.dart';

/// [ColorScheme] 기반 시맨틱 색 — 라이트/다크 자동 대응.
///
/// UI 카드·테두리·뱃지 등은 [AppColors] 고정값 대신 이 확장을 사용한다.
extension AppThemeColors on ColorScheme {
  Color get appCardSurface => surface;

  Color get appBorder => outlineVariant;

  Color get appDivider => outlineVariant.withValues(alpha: 0.42);

  Color get appIconBadge => primaryContainer;

  Color get appInsetFill => surfaceContainerLow;

  Color get appMutedFill => surfaceContainer;
}
