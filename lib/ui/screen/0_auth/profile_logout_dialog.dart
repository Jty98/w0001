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

/// 로그아웃 확인 결과. `null`이면 취소.
class ProfileLogoutChoice {
  const ProfileLogoutChoice({required this.allDevices});

  /// true → `POST /auth/logout-all`, false → `POST /auth/logout` + refresh_token
  final bool allDevices;
}

Future<ProfileLogoutChoice?> showProfileLogoutConfirmDialog(
  BuildContext context,
) async {
  var logoutAllDevices = false;

  final r = await showDialog<ProfileLogoutChoice>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return StatefulBuilder(
        builder: (ctx, setLocalState) {
          return AuthDialogChrome(
            icon: Icons.logout_rounded,
            iconForegroundColor: cs.error,
            iconBackgroundColor: cs.errorContainer.withValues(alpha: 0.45),
            title: const Text('로그아웃'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  logoutAllDevices
                      ? '모든 기기에서 로그아웃합니다. 다른 폰·태블릿에서도 다시 로그인해야 합니다.'
                      : '이 기기에 저장된 로그인 정보만 삭제합니다.',
                  style: _bodyStyle(ctx),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: logoutAllDevices,
                  onChanged: (v) =>
                      setLocalState(() => logoutAllDevices = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    '모든 기기에서 로그아웃',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    '다른 기기에서 쓰던 세션도 함께 종료합니다.',
                    style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            actions: AuthDialogActionsDual(
              secondaryLabel: '취소',
              secondaryOnPressed: () => Navigator.of(ctx).pop(),
              primaryLabel: '로그아웃',
              primaryOnPressed: () => Navigator.of(ctx).pop(
                ProfileLogoutChoice(allDevices: logoutAllDevices),
              ),
              primaryStyleOverride: AuthDialogChromeTheme.primaryFilled(
                ctx,
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
            ),
          );
        },
      );
    },
  );
  return r;
}
