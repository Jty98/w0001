import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:w0001/ui/screen/0_auth/auth_dialog_chrome.dart';
import 'package:w0001/util/auth_api_user_messages.dart';
import 'package:w0001/util/auth_dio_user_message.dart';

TextStyle _bodyStyle(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  return (tt.bodyLarge ?? const TextStyle()).copyWith(
    color: cs.onSurfaceVariant,
    height: 1.52,
    letterSpacing: -0.06,
  );
}

/// [ACCOUNT_REJECTED] / [ACCOUNT_SUSPENDED] 일 때 로그인 화면 전용 다이얼로그.
///
/// 표시했다면 true (호출측 스낵바 스킵).
Future<bool> showLoginAccountRestrictedDialogIfApplicable(
  BuildContext context,
  DioException e,
) async {
  final d = tryParseAuthStructuredDetail(e.response?.data);
  if (d == null) return false;

  if (d.code != AuthApiErrorCodes.accountRejected &&
      d.code != AuthApiErrorCodes.accountSuspended) {
    return false;
  }

  if (!context.mounted) return true;

  final body = localizedAuthDetailMessage(
    httpStatusCode: e.response?.statusCode,
    responseData: e.response?.data,
  );
  final text = body.trim().isNotEmpty ? body : dioAuthRelatedUserMessage(e);

  final rejected = d.code == AuthApiErrorCodes.accountRejected;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AuthDialogChrome(
        icon: rejected
            ? Icons.cancel_outlined
            : Icons.pause_circle_outline_rounded,
        iconForegroundColor: rejected ? cs.error : cs.tertiary,
        iconBackgroundColor: rejected
            ? cs.errorContainer.withValues(alpha: 0.55)
            : cs.tertiaryContainer.withValues(alpha: 0.52),
        title: Text(rejected ? '가입 거절' : '계정 정지'),
        content:
            SingleChildScrollView(child: Text(text, style: _bodyStyle(ctx))),
        actions: AuthDialogActionsSingle(
          label: '확인',
          onPressed: () => Navigator.of(ctx).pop(),
          expandWidth: true,
        ),
      );
    },
  );
  return true;
}
