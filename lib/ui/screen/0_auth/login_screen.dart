import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/theme/app_colors.dart';
import 'package:w0001/ui/screen/0_auth/login_auth_dialogs.dart';
import 'package:w0001/ui/widget/keyboard_aware.dart';
import 'package:w0001/ui/widget/responsive_page_shell.dart';
import 'package:w0001/ui/widget/round_text_field.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/auth_dio_user_message.dart';
import 'package:w0001/util/fcm/fcm_bootstrap.dart';
import 'package:w0001/util/fcm/fcm_push_router.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/login_preferences.dart';
import 'package:w0001/util/clear_user_providers.dart';

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

      // 이전 계정 캐시 제거 후 세션·역할별 데이터를 UI 진입 전에 채운다.
      _clearAllProviders(ref);

      await ref
          .read(authSessionProvider.notifier)
          .loadCurrentUser(awaitWarmUp: true);
      if (!mounted) return;
      final session = ref.read(authSessionProvider);
      final user = session.asData?.value;
      if (session.hasError || user == null) {
        _toast(
          context,
          session.hasError
              ? '로그인은 완료되었으나 내 정보를 불러오지 못했습니다. 다시 시도해 주세요.'
              : '로그인 정보를 확인하지 못했습니다. 다시 시도해 주세요.',
        );
        return;
      }
      final restriction = accountRestrictionKindForUser(user);
      if (restriction != null) {
        try {
          await ref.read(authUseCaseProvider).logout();
        } catch (_) {}
        _clearAllProviders(ref);
        ref.read(authSessionProvider.notifier).clearSession();
        if (!mounted) return;
        await showAccountRestrictedStatusDialog(
          context,
          kind: restriction,
        );
        return;
      }
      final root = rootProviderContainer;
      if (root != null) {
        final fcmOk = await registerFcmTokenForLoggedInUser(root, force: true);
        if (kDebugMode && !fcmOk) {
          debugPrint('FCM registration failed after login uid=${user.uid}');
        }
      }
      if (user.isPendingApproval) {
        context.go('/pending-approval');
      } else {
        context.go('/dashboard');
      }
      if (!session.hasError) {
        final root = rootProviderContainer;
        if (root != null) {
          unawaited(tryConsumePendingPostAuthFcmNavigation(root));
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final restricted =
          await showLoginAccountRestrictedDialogIfApplicable(context, e);
      if (!mounted) return;
      if (!restricted) {
        _toast(context, dioAuthRelatedUserMessage(e));
      }
    } catch (e) {
      if (!mounted) return;
      _toast(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  /// 로그인 시 모든 provider 초기화 (이전 사용자의 캐시된 데이터 제거)
  void _clearAllProviders(WidgetRef ref) {
    clearAllUserProvidersWithRef(ref);
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _passwordVisibilitySuffix(ColorScheme cs) {
    return IconButton(
      tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints(
        minWidth: context.rs(36),
        maxWidth: context.rs(36),
        minHeight: context.rs(36),
        maxHeight: context.rs(36),
      ),
      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      icon: Icon(
        _obscurePassword
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        size: context.rs(20),
        color: cs.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        cs.surface,
                        cs.surfaceContainerLow,
                        cs.surfaceContainer,
                      ]
                    : [
                        AppColors.primaryColor.withValues(alpha: 0.22),
                        AppColors.backgroundColor,
                        AppColors.accentColor.withValues(alpha: 0.35),
                      ],
                stops: const [0.0, 0.42, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return KeyboardAwareScrollView(
                  autoScrollOnFocus: false,
                  child: ResponsivePageShell(
                    padding: ResponsiveLayout.symmetric(
                      context,
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: AutofillGroup(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            rsV(context, 8),
                            Container(
                              width: context.rs(88),
                              height: context.rs(88),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(context.rs(24)),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withValues(alpha: 0.5)
                                        : AppColors.primaryColor
                                            .withValues(alpha: 0.18),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                fit: BoxFit.cover,
                                width: context.rs(88),
                                height: context.rs(88),
                              ),
                            ),
                            rsV(context, 28),
                            Text(
                              '현장좋아',
                              textAlign: TextAlign.center,
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                                color: cs.onSurface,
                              ),
                            ),
                            rsV(context, 36),
                            Material(
                              color:
                                  isDark ? cs.surfaceContainerHigh : cs.surface,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(context.rs(20)),
                              child: Container(
                                width: double.infinity,
                                padding: ResponsiveLayout.only(
                                  context,
                                  left: 22,
                                  top: 26,
                                  right: 22,
                                  bottom: 22,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(context.rs(20)),
                                  border: Border.all(
                                    color: isDark
                                        ? cs.outline.withValues(alpha: 0.3)
                                        : cs.outlineVariant
                                            .withValues(alpha: 0.5),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withValues(alpha: 0.3)
                                          : cs.shadow.withValues(alpha: 0.06),
                                      blurRadius: 32,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    RoundTextField(
                                      controller: _idController,
                                      keyboardType: TextInputType.text,
                                      onChanged: (_) {},
                                      labelText: '아이디',
                                      showClearButton: true,
                                      scrollPaddingExtra: 24,
                                      autofillHints: const [
                                        AutofillHints.username,
                                      ],
                                    ),
                                    rsV(context, 4),
                                    RoundTextField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      onChanged: (_) {},
                                      labelText: '비밀번호',
                                      showClearButton: true,
                                      scrollPaddingExtra: 24,
                                      autofillHints: const [
                                        AutofillHints.password
                                      ],
                                      suffixIcon: _passwordVisibilitySuffix(cs),
                                    ),
                                    rsV(context, 6),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final narrow = constraints.maxWidth <
                                            context.rs(340);
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
                                              rsV(context, 2),
                                              autoLoginTile,
                                            ],
                                          );
                                        }
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: saveIdTile),
                                            Padding(
                                              padding: EdgeInsets.only(
                                                top: context.rs(10),
                                              ),
                                              child: SizedBox(
                                                height: context.rs(22),
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
                                    rsV(context, 20),
                                    FilledButton(
                                      onPressed: _submitting ? null : _onLogin,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: cs.primary,
                                        foregroundColor: cs.onPrimary,
                                        minimumSize:
                                            Size.fromHeight(context.rs(52)),
                                        padding: ResponsiveLayout.symmetric(
                                          context,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              context.rs(12)),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Skeletonizer(
                                        enabled: _submitting,
                                        child: Text(
                                          '로그인',
                                          style:
                                              textTheme.titleMedium?.copyWith(
                                            color: cs.onPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            rsV(context, 12),
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => context.push('/signup'),
                              child: Text(
                                '계정이 없으신가요? 회원가입',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            rsV(context, 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
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
        padding: ResponsiveLayout.symmetric(context, vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: context.rs(40),
              height: context.rs(40),
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
