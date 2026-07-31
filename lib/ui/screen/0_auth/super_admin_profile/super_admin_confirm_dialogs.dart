import 'package:flutter/material.dart';
import 'package:w0001/ui/screen/0_auth/auth_dialog_chrome.dart';
import 'package:w0001/ui/widget/app_text_field.dart';

TextStyle _bodyStyle(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  return (tt.bodyLarge ?? const TextStyle()).copyWith(
    color: cs.onSurfaceVariant,
    height: 1.52,
    letterSpacing: -0.06,
    fontWeight: FontWeight.w400,
  );
}

/// 취소 시 null, 확정 시 (true, 메모 trim).
///
/// [TextEditingController] 은 라우트 트리가 완전히 버려진 뒤 dispose 되도록 [StatefulWidget] 안에서만 관리한다.
Future<(bool confirmed, String note)?> showSuperAdminConfirmWithNoteDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String affirmativeLabel,
  required String hint,
  ButtonStyle? affirmativeStyle,
}) {
  return showDialog<(bool confirmed, String note)?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SuperAdminConfirmWithNoteDialog(
      title: title,
      body: body,
      affirmativeLabel: affirmativeLabel,
      hint: hint,
      affirmativeStyle: affirmativeStyle,
    ),
  );
}

class _SuperAdminConfirmWithNoteDialog extends StatefulWidget {
  const _SuperAdminConfirmWithNoteDialog({
    required this.title,
    required this.body,
    required this.affirmativeLabel,
    required this.hint,
    this.affirmativeStyle,
  });

  final String title;
  final String body;
  final String affirmativeLabel;
  final String hint;
  final ButtonStyle? affirmativeStyle;

  @override
  State<_SuperAdminConfirmWithNoteDialog> createState() =>
      _SuperAdminConfirmWithNoteDialogState();
}

class _SuperAdminConfirmWithNoteDialogState
    extends State<_SuperAdminConfirmWithNoteDialog> {
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ButtonStyle mergedPrimary(BuildContext ctx) =>
        AuthDialogChromeTheme.primaryFilled(ctx).merge(widget.affirmativeStyle);

    return AuthDialogChrome(
      icon: Icons.edit_note_rounded,
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.body, style: _bodyStyle(context)),
            const SizedBox(height: 16),
            AppTextField(
              controller: _noteCtrl,
              decoration: AuthDialogChromeTheme.inputDecoration(
                context: context,
                labelText: widget.hint,
                hintText: widget.hint,
              ),
              style: Theme.of(context).textTheme.bodyLarge,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
            ),
          ],
        ),
      ),
      actions: AuthDialogActionsDual(
        secondaryLabel: '취소',
        secondaryOnPressed: () => Navigator.of(context).pop(),
        primaryLabel: widget.affirmativeLabel,
        primaryOnPressed: () => Navigator.of(context).pop(
          (true, _noteCtrl.text.trim()),
        ),
        primaryStyleOverride: mergedPrimary(context),
      ),
    );
  }
}

Future<bool> showSuperAdminSimpleConfirmDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  ButtonStyle? confirmStyle,
}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final merged =
          AuthDialogChromeTheme.primaryFilled(ctx).merge(confirmStyle);
      return AuthDialogChrome(
        icon: Icons.info_outline_rounded,
        iconForegroundColor: Theme.of(context).colorScheme.secondary,
        iconBackgroundColor:
            Theme.of(context).colorScheme.secondaryContainer.withValues(
                  alpha: 0.6,
                ),
        title: Text(title),
        content:
            SingleChildScrollView(child: Text(body, style: _bodyStyle(ctx))),
        actions: AuthDialogActionsDual(
          secondaryLabel: '취소',
          secondaryOnPressed: () => Navigator.pop(ctx, false),
          primaryLabel: confirmLabel,
          primaryOnPressed: () => Navigator.pop(ctx, true),
          primaryStyleOverride: merged,
        ),
      );
    },
  );
  return r == true;
}

/// 취소 시 null. 확정 시 비밀번호(앞뒤 공백 trim).
Future<String?> showSuperAdminSensitiveActionPasswordDialog({
  required BuildContext context,
  required String title,
  required String body,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SuperAdminSensitiveActionPasswordDialog(
      title: title,
      body: body,
    ),
  );
}

class _SuperAdminSensitiveActionPasswordDialog extends StatefulWidget {
  const _SuperAdminSensitiveActionPasswordDialog({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  State<_SuperAdminSensitiveActionPasswordDialog> createState() =>
      _SuperAdminSensitiveActionPasswordDialogState();
}

class _SuperAdminSensitiveActionPasswordDialogState
    extends State<_SuperAdminSensitiveActionPasswordDialog> {
  late final TextEditingController _pwCtrl;
  var _obscure = true;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _pwCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _pwCtrl.text.trim();
    if (t.isEmpty) {
      setState(() => _inlineError = '비밀번호를 입력해 주세요.');
      return;
    }
    Navigator.of(context).pop(t);
  }

  @override
  Widget build(BuildContext context) {
    return AuthDialogChrome(
      icon: Icons.lock_outline_rounded,
      iconForegroundColor: Theme.of(context).colorScheme.tertiary,
      iconBackgroundColor: Theme.of(context)
          .colorScheme
          .tertiaryContainer
          .withValues(alpha: 0.55),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.body, style: _bodyStyle(context)),
            const SizedBox(height: 16),
            AppTextField(
              controller: _pwCtrl,
              autofocus: true,
              obscureText: _obscure,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: AuthDialogChromeTheme.inputDecoration(
                context: context,
                labelText: '관리자 비밀번호',
                errorText: _inlineError,
                suffixIcon: IconButton(
                  tooltip: _obscure ? '표시' : '숨기기',
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onChanged: (_) {
                if (_inlineError != null) {
                  setState(() => _inlineError = null);
                }
              },
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
      actions: AuthDialogActionsDual(
        secondaryLabel: '취소',
        secondaryOnPressed: () => Navigator.of(context).pop(),
        primaryLabel: '확인',
        primaryOnPressed: _submit,
      ),
    );
  }
}

Future<bool> showSuperAdminDeleteUserConfirmDialog({
  required BuildContext context,
  required String uname,
}) async {
  final cs = Theme.of(context).colorScheme;
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AuthDialogChrome(
        icon: Icons.warning_amber_rounded,
        iconForegroundColor: cs.error,
        iconBackgroundColor: cs.errorContainer.withValues(alpha: 0.72),
        title: Text('$uname 삭제'),
        content: Text(
          '서버에서 이 계정을 완전히 삭제합니다. 되돌릴 수 없습니다.',
          style: _bodyStyle(ctx),
        ),
        actions: AuthDialogActionsDual(
          secondaryLabel: '취소',
          secondaryOnPressed: () => Navigator.of(ctx).pop(false),
          primaryLabel: '삭제',
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
