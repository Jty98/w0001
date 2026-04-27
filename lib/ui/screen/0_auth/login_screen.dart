import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/ui/widget/round_text_field.dart';
import 'package:w0001/util/login_preferences.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  var _autoLogin = false;
  var _saveId = false;
  var _obscurePassword = true;
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrefs());
  }

  Future<void> _loadPrefs() async {
    final data = await LoginPreferences.load();
    if (!mounted) return;
    setState(() {
      _autoLogin = data.autoLogin;
      _saveId = data.saveId;
      if (data.saveId && data.savedUid != null && data.savedUid!.isNotEmpty) {
        _idController.text = data.savedUid!;
      }
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_submitting) return;
    final uid = _idController.text.trim();
    final upw = _passwordController.text;
    if (uid.isEmpty) {
      _toast(context, '아이디를 입력해 주세요.');
      return;
    }
    if (upw.isEmpty) {
      _toast(context, '비밀번호를 입력해 주세요.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final auth = ref.read(authUseCaseProvider);
      await auth.login(uid: uid, upw: upw);
      await LoginPreferences.applyAfterSuccess(
        autoLogin: _autoLogin,
        saveId: _saveId,
        currentUid: uid,
      );
      await ref.read(authSessionProvider.notifier).loadCurrentUser();
      if (!mounted) return;
      final me = ref.read(authSessionProvider);
      if (me.hasError) {
        _toast(
          context,
          '로그인은 완료되었으나 내 정보를 불러오지 못했습니다. 프로필에서 다시 시도하세요.',
        );
      }
      if (!mounted) return;
      context.go('/dashboard');
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.httpClientError?.message ?? e.message ?? '로그인에 실패했습니다.';
      _toast(context, msg);
    } catch (e) {
      if (!mounted) return;
      _toast(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primaryContainer.withValues(alpha: 0.45),
                  cs.surface,
                  cs.tertiaryContainer.withValues(alpha: 0.2),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.home_repair_service_rounded,
                          size: 44,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        '인테리어 정산',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '현장·인건비·자재를 한곳에서 정리하세요',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 36),
                      Material(
                        color: cs.surface,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cs.shadow.withValues(alpha: 0.06),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              RoundTextField(
                                controller: _idController,
                                keyboardType: TextInputType.text,
                                onChanged: (_) {},
                                labelText: '아이디',
                                autofillHints: const [AutofillHints.username],
                              ),
                              const SizedBox(height: 4),
                              RoundTextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                onChanged: (_) {},
                                labelText: '비밀번호',
                                autofillHints: const [AutofillHints.password],
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final narrow = constraints.maxWidth < 340;
                                  final saveIdTile = _optionCheckbox(
                                    textTheme: textTheme,
                                    cs: cs,
                                    value: _saveId,
                                    label: '아이디 저장',
                                    onChanged: (v) {
                                      setState(() {
                                        _saveId = v ?? false;
                                      });
                                    },
                                  );
                                  final autoLoginTile = _optionCheckbox(
                                    textTheme: textTheme,
                                    cs: cs,
                                    value: _autoLogin,
                                    label: '자동 로그인',
                                    onChanged: (v) {
                                      setState(() {
                                        _autoLogin = v ?? false;
                                      });
                                    },
                                  );
                                  if (narrow) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        saveIdTile,
                                        const SizedBox(height: 2),
                                        autoLoginTile,
                                      ],
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: saveIdTile),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: SizedBox(
                                          height: 22,
                                          child: VerticalDivider(
                                            width: 1,
                                            thickness: 1,
                                            color: cs.outlineVariant
                                                .withValues(alpha: 0.55),
                                          ),
                                        ),
                                      ),
                                      Expanded(child: autoLoginTile),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _submitting ? null : _onLogin,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
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
                                    : Text(
                                        '로그인',
                                        style: textTheme.titleMedium?.copyWith(
                                          color: cs.onPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 한 줄 옵션: 체크박스 + 탭 가능한 라벨 (짧은 라벨은 [bodyMedium])
  Widget _optionCheckbox({
    required TextTheme textTheme,
    required ColorScheme cs,
    required bool value,
    required String label,
    required void Function(bool?) onChanged,
  }) {
    final style = textTheme.bodyMedium?.copyWith(
      color: cs.onSurface,
      height: 1.2,
    );
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
