import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/user_account_providers.dart';
import 'package:w0001/util/auth_api_user_messages.dart';
import 'package:w0001/util/responsive_layout.dart';

class _PasswordChangeResult {
  const _PasswordChangeResult({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;
}

class _PasswordChangeDialog extends StatefulWidget {
  const _PasswordChangeDialog();

  @override
  State<_PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<_PasswordChangeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _currentController;
  late final TextEditingController _newController;
  late final TextEditingController _confirmController;
  var _obscureCurrent = true;
  var _obscureNew = true;
  var _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _currentController = TextEditingController();
    _newController = TextEditingController();
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(
      _PasswordChangeResult(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('비밀번호 변경'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: '현재 비밀번호',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return '현재 비밀번호를 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: '새 비밀번호',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return '새 비밀번호를 입력해 주세요.';
                  }
                  if (v.length < 4) {
                    return '비밀번호는 4자 이상이어야 합니다.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: '새 비밀번호 확인',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v != _newController.text) {
                    return '비밀번호가 일치하지 않습니다.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                '변경 후 모든 기기에서 로그아웃됩니다. 다시 로그인해 주세요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('변경'),
        ),
      ],
    );
  }
}

/// 비밀번호 변경 타일 (`PATCH /users/me/account`).
class ProfilePasswordEditTile extends ConsumerWidget {
  const ProfilePasswordEditTile({super.key});

  String _errorMessage(Object e) {
    if (e is DioException) {
      final msg = localizedAuthDetailMessage(
        httpStatusCode: e.response?.statusCode,
        responseData: e.response?.data,
      );
      if (msg.trim().isNotEmpty) return msg;
    }
    return '비밀번호 변경에 실패했습니다.';
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_PasswordChangeResult>(
      context: context,
      builder: (ctx) => const _PasswordChangeDialog(),
    );

    if (result == null || !context.mounted) return;

    try {
      await ref.read(userAccountProvider.notifier).updatePassword(
            currentPassword: result.currentPassword,
            newPassword: result.newPassword,
          );
      await ref.read(authUseCaseProvider).logout();
      ref.read(authSessionProvider.notifier).clearSession();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호가 변경되었습니다. 다시 로그인해 주세요.'),
        ),
      );
      context.go('/login');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      leading: Icon(
        Icons.lock_outline_rounded,
        color: cs.primary,
        size: context.rsi(22),
      ),
      title: Text(
        '비밀번호 변경',
        style: TextStyle(fontSize: context.rs(14)),
      ),
      subtitle: Text(
        '보안을 위해 주기적으로 변경하세요',
        style: TextStyle(fontSize: context.rs(12)),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: context.rsi(20),
      ),
      onTap: () => _showEditDialog(context, ref),
    );
  }
}
