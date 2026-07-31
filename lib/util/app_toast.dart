import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/stacked_toast_overlay.dart';

/// 앱 전역 스택형 토스트 — [ScaffoldMessenger] 큐를 우회한다.
abstract final class AppToast {
  static const maxDuration = Duration(milliseconds: 2600);

  static void show(
    String message, {
    Duration? duration,
    Color? backgroundColor,
    VoidCallback? onTap,
    bool dismissOnTap = true,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    final d = duration ?? StackedToastController.defaultDuration;
    final clamped = d > maxDuration ? maxDuration : d;

    StackedToastController.instance.show(
      trimmed,
      duration: clamped,
      backgroundColor: backgroundColor,
      onTap: onTap,
      dismissOnTap: dismissOnTap,
    );
  }

  static void showSnackBar(SnackBar snackBar) {
    final message = snackBarContentText(snackBar.content);
    if (message.isEmpty) return;
    show(
      message,
      duration: snackBar.duration,
      backgroundColor: snackBar.backgroundColor,
    );
  }

  static void clear() => StackedToastController.instance.clearAll();
}

/// [ScaffoldMessenger.of(context).showSnackBar] 대체용.
extension AppToastBuildContext on BuildContext {
  void showAppSnackBar(
    String message, {
    Duration? duration,
    Color? backgroundColor,
  }) {
    AppToast.show(
      message,
      duration: duration,
      backgroundColor: backgroundColor,
    );
  }
}
