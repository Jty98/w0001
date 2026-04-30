import 'package:flutter/material.dart';
import 'package:w0001/ui/screen/0_auth/auth_dialog_chrome.dart';

TextStyle _bodyStyle(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  return (tt.bodyLarge ?? const TextStyle()).copyWith(
    color: cs.onSurfaceVariant,
    height: 1.52,
    letterSpacing: -0.06,
  );
}

Future<bool> showProfileLogoutConfirmDialog(BuildContext context) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AuthDialogChrome(
        icon: Icons.logout_rounded,
        iconForegroundColor: cs.error,
        iconBackgroundColor:
            cs.errorContainer.withValues(alpha: 0.45),
        title: const Text('로그아웃'),
        content: Text('로그아웃하면 이 기기에 저장된 로그인 정보만 삭제됩니다.', style: _bodyStyle(ctx)),
        actions: AuthDialogActionsDual(
          secondaryLabel: '취소',
          secondaryOnPressed: () => Navigator.of(ctx).pop(false),
          primaryLabel: '로그아웃',
          primaryOnPressed: () => Navigator.of(ctx).pop(true),
          primaryStyleOverride: AuthDialogChromeTheme.primaryFilled(
            ctx,
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
        ),
      );
    },
  );
  return r == true;
}
