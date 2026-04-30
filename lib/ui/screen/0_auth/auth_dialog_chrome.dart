import 'package:flutter/material.dart';

/// 인증·슈퍼관리자 계열 확인창 공통 레이아웃 (코너·여백·타이포·버튼 높이).
abstract final class AuthDialogChromeTheme {
  static const double radius = 26;
  static const double actionMinHeight = 46;
  static const double maxContentWidth = 400;

  static RoundedRectangleBorder dialogShape(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
    );
  }

  static EdgeInsets get outerInsets =>
      const EdgeInsets.symmetric(horizontal: 20, vertical: 28);

  static ButtonStyle secondaryButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton.styleFrom(
      minimumSize: const Size(0, actionMinHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      foregroundColor: cs.onSurfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    );
  }

  static ButtonStyle primaryFilled(
    BuildContext context, {
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      minimumSize: const Size(0, actionMinHeight),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      elevation: 0,
      backgroundColor: backgroundColor ?? cs.primary,
      foregroundColor: foregroundColor ?? cs.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    );
  }

  /// 본문·메모 입력 등에 사용.
  static InputDecoration inputDecoration({
    required BuildContext context,
    String? labelText,
    String? hintText,
    String? errorText,
    Widget? suffixIcon,
  }) {
    final cs = Theme.of(context).colorScheme;
    final base = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText ?? labelText,
      errorText: errorText,
      alignLabelWithHint: true,
      filled: true,
      fillColor: cs.surfaceContainerLow.withValues(alpha: 0.82),
      suffixIcon: suffixIcon,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: base.copyWith(borderSide: BorderSide.none),
      enabledBorder: base.copyWith(
        borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      focusedBorder: base.copyWith(
        borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.65)),
      ),
      errorBorder: base.copyWith(
        borderSide: BorderSide(color: cs.error.withValues(alpha: 0.65)),
      ),
    );
  }
}

/// 재사용 가능한 둥근 [Dialog] 셸. [actions] 는 전체 너비 기준 레이아웃.
class AuthDialogChrome extends StatelessWidget {
  const AuthDialogChrome({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
    this.iconBackgroundColor,
    this.iconForegroundColor,
  });

  final Widget title;
  final Widget content;
  final Widget actions;

  /// 상단 장식 아이콘 (없으면 생략)
  final IconData? icon;

  /// [icon] 배경 원 색 (기본: primaryContainer 계열)
  final Color? iconBackgroundColor;

  /// [icon] 색 (기본: primary)
  final Color? iconForegroundColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final iconBg =
        iconBackgroundColor ?? cs.primaryContainer.withValues(alpha: 0.55);
    final iconFg = iconForegroundColor ?? cs.primary;

    return Dialog(
      backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 0.98),
      insetPadding: AuthDialogChromeTheme.outerInsets,
      shape: AuthDialogChromeTheme.dialogShape(context),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: AuthDialogChromeTheme.maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: cs.shadow.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(icon, size: 26, color: iconFg),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              DefaultTextStyle(
                style: (tt.titleLarge ?? const TextStyle()).copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.45,
                  color: cs.onSurface,
                  height: 1.2,
                ),
                child: title,
              ),
              const SizedBox(height: 14),
              content,
              const SizedBox(height: 22),
              actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// 두 단 액션: 취소(좌)·확정(우) 동일 폭.
class AuthDialogActionsDual extends StatelessWidget {
  const AuthDialogActionsDual({
    super.key,
    required this.secondaryLabel,
    required this.secondaryOnPressed,
    required this.primaryLabel,
    required this.primaryOnPressed,
    this.secondaryStyleOverride,
    this.primaryStyleOverride,
  });

  final String secondaryLabel;
  final VoidCallback secondaryOnPressed;
  final String primaryLabel;
  final VoidCallback primaryOnPressed;

  /// 예: 에러 테마 취소 아님 — 보통 null
  final ButtonStyle? secondaryStyleOverride;

  final ButtonStyle? primaryStyleOverride;

  @override
  Widget build(BuildContext context) {
    final secondaryStyle =
        secondaryStyleOverride ?? AuthDialogChromeTheme.secondaryButton(context);

    final primaryStyle =
        primaryStyleOverride ?? AuthDialogChromeTheme.primaryFilled(context);

    return Row(
      children: [
        Expanded(
          child: TextButton(
            style: secondaryStyle,
            onPressed: secondaryOnPressed,
            child: Text(secondaryLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            style: primaryStyle,
            onPressed: primaryOnPressed,
            child: Text(primaryLabel),
          ),
        ),
      ],
    );
  }
}

/// 단일 확인 버튼 (전체 너비).
class AuthDialogActionsSingle extends StatelessWidget {
  const AuthDialogActionsSingle({
    super.key,
    required this.label,
    required this.onPressed,
    this.styleOverride,
    this.expandWidth = true,
  });

  final String label;
  final VoidCallback onPressed;
  final ButtonStyle? styleOverride;
  final bool expandWidth;

  @override
  Widget build(BuildContext context) {
    final btn = FilledButton(
      style:
          styleOverride ?? AuthDialogChromeTheme.primaryFilled(context),
      onPressed: onPressed,
      child: Text(label),
    );
    if (expandWidth) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}
