import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/ui/widget/round_text_field.dart';
import 'package:w0001/util/auth_dio_user_message.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _uidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _unameController = TextEditingController();
  var _obscurePassword = true;
  var _submitting = false;

  @override
  void dispose() {
    _uidController.dispose();
    _passwordController.dispose();
    _unameController.dispose();
    super.dispose();
  }

  Future<void> _onSignup() async {
    if (_submitting) return;
    final uid = _uidController.text.trim();
    final upw = _passwordController.text;
    final uname = _unameController.text.trim();

    if (uid.isEmpty) {
      _toast('아이디를 입력해 주세요.');
      return;
    }
    if (uname.isEmpty) {
      _toast('이름(표시 이름)을 입력해 주세요.');
      return;
    }
    if (upw.isEmpty) {
      _toast('비밀번호를 입력해 주세요.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authUseCaseProvider).signup(
            uid: uid,
            upw: upw,
            uname: uname,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('가입 요청 완료'),
          content: const Text(
            '가입 요청이 접수되었습니다. 관리자 승인 후 로그인할 수 있습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      if (mounted) context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      _toast(dioAuthRelatedUserMessage(e));
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '아이디·비밀번호·이름을 입력해 주세요.\n관리자 승인 후 서비스를 이용할 수 있습니다.',
                style: textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              RoundTextField(
                controller: _uidController,
                keyboardType: TextInputType.text,
                onChanged: (_) {},
                labelText: '아이디',
              ),
              const SizedBox(height: 12),
              RoundTextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                onChanged: (_) {},
                labelText: '비밀번호',
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RoundTextField(
                controller: _unameController,
                keyboardType: TextInputType.name,
                onChanged: (_) {},
                labelText: '이름 (표시 이름)',
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _submitting ? null : _onSignup,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Text('가입 요청'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _submitting ? null : () => context.pop(),
                child: const Text('로그인으로 돌아가기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
