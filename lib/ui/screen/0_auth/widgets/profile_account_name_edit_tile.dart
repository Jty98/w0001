import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/user_account_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/user_account_providers.dart';
import 'package:w0001/util/auth_api_user_messages.dart';
import 'package:w0001/util/responsive_layout.dart';

class _NameEditDialog extends StatefulWidget {
  const _NameEditDialog({required this.initialName});

  final String initialName;

  @override
  State<_NameEditDialog> createState() => _NameEditDialogState();
}

class _NameEditDialogState extends State<_NameEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('이름 수정'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '이름',
            hintText: '표시 이름',
          ),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return '이름을 입력해 주세요.';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('저장'),
        ),
      ],
    );
  }
}

/// 계정 이름 수정 타일 (`PATCH /users/me/account`).
class ProfileAccountNameEditTile extends ConsumerWidget {
  const ProfileAccountNameEditTile({super.key, required this.account});

  final UserAccountRead account;

  String _errorMessage(Object e) {
    if (e is DioException) {
      final msg = localizedAuthDetailMessage(
        httpStatusCode: e.response?.statusCode,
        responseData: e.response?.data,
      );
      if (msg.trim().isNotEmpty) return msg;
    }
    return e.toString();
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _NameEditDialog(initialName: account.uname),
    );

    if (newName == null || !context.mounted) return;
    if (newName == account.uname) return;

    try {
      await ref.read(userAccountProvider.notifier).updateName(newName);
      await ref.read(authSessionProvider.notifier).loadCurrentUser();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름이 변경되었습니다.')),
      );
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
        Icons.edit_outlined,
        color: cs.primary,
        size: context.rsi(22),
      ),
      title: Text(
        '이름 수정',
        style: TextStyle(fontSize: context.rs(14)),
      ),
      subtitle: Text(
        '현재: ${account.uname}',
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
