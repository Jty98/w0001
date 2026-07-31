import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/phone_mo_verification_providers.dart';
import 'package:w0001/presentation/viewmodel/user_account_providers.dart';
import 'package:w0001/util/auth_api_user_messages.dart';
import 'package:w0001/util/phone_number_format.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/widget/app_text_field.dart';

/// 작업자 전화번호 설정/인증 화면
class PhoneSettingScreen extends ConsumerStatefulWidget {
  const PhoneSettingScreen({super.key});

  @override
  ConsumerState<PhoneSettingScreen> createState() => _PhoneSettingScreenState();
}

class _PhoneSettingScreenState extends ConsumerState<PhoneSettingScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  var _isVerifying = false;
  var _verificationStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(userAccountProvider);
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _startVerification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isVerifying = true);

    try {
      final phone = _phoneController.text.trim();
      final notifier = ref.read(phoneMoVerificationNotifierProvider.notifier);

      await notifier.startVerification(phone);

      if (!mounted) return;

      setState(() {
        _verificationStarted = true;
        _isVerifying = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인증 문자를 발송했습니다. 문자앱에서 인증을 완료해주세요.'),
          duration: Duration(seconds: 4),
        ),
      );

      // 인증 완료 대기
      _waitForVerification();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('인증 시작 실패: $e')),
      );
    }
  }

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

  Future<void> _waitForVerification() async {
    final phone = _phoneController.text.trim();
    final notifier = ref.read(phoneMoVerificationNotifierProvider.notifier);

    try {
      final token = await notifier.waitForVerification(phone);

      await ref.read(userAccountProvider.notifier).updatePhone(
            phone: phone,
            phoneVerificationToken: token,
          );

      if (!mounted) return;

      await Future.wait([
        ref.read(authSessionProvider.notifier).loadCurrentUser(),
        ref.read(userAccountProvider.notifier).reload(),
      ]);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전화번호가 등록되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _verificationStarted = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('인증 실패: ${_errorMessage(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final account = ref.watch(userAccountProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('전화번호 설정'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.rsi(20)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 현재 등록된 전화번호
              if (account?.phoneMasked != null &&
                  account!.phoneMasked!.isNotEmpty) ...[
                AppInsetCard(
                  padding: EdgeInsets.all(context.rsi(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: context.rsi(20),
                            color: cs.primary,
                          ),
                          rsH(context, 8),
                          Text(
                            '현재 등록된 전화번호',
                            style: tt.labelLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      rsV(context, 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              account.phoneMasked!,
                              style: tt.headlineSmall?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            account.phoneVerified
                                ? Icons.verified_rounded
                                : Icons.warning_amber_rounded,
                            color: account.phoneVerified
                                ? cs.primary
                                : cs.error.withValues(alpha: 0.7),
                            size: context.rsi(24),
                          ),
                          rsH(context, 4),
                          Text(
                            account.phoneVerified ? '인증됨' : '미인증',
                            style: tt.labelMedium?.copyWith(
                              color: account.phoneVerified
                                  ? cs.primary
                                  : cs.error.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                rsV(context, 24),
              ],

              // 전화번호 변경 안내
              Text(
                '새 전화번호 입력',
                style: tt.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              rsV(context, 8),
              Text(
                '전화번호를 변경하려면 새로운 번호를 입력하고 인증을 완료해주세요.',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              rsV(context, 16),

              // 전화번호 입력
              AppTextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_verificationStarted && !_isVerifying,
                decoration: InputDecoration(
                  labelText: '전화번호',
                  hintText: '010-1234-5678',
                  prefixIcon: const Icon(Icons.phone_android_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '전화번호를 입력해주세요.';
                  }
                  final normalized = normalizeKoreanMobilePhone(value);
                  if (normalized.isEmpty) {
                    return '올바른 전화번호를 입력해주세요.';
                  }
                  return null;
                },
              ),
              rsV(context, 24),

              // 인증 버튼
              if (!_verificationStarted) ...[
                FilledButton.icon(
                  onPressed: _isVerifying ? null : _startVerification,
                  icon: _isVerifying
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: const HammerLoadingIndicator(size: 20),
                        )
                      : const Icon(Icons.verified_user_rounded),
                  label: Text(_isVerifying ? '인증 시작 중...' : '인증 시작'),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: context.rsi(16)),
                  ),
                ),
              ],

              // 인증 대기 중
              if (_verificationStarted) ...[
                AppInsetTile(
                  borderRadius: BorderRadius.circular(12),
                  backgroundColor: cs.primaryContainer.withValues(alpha: 0.3),
                  padding: EdgeInsets.all(context.rsi(16)),
                  child: Column(
                    children: [
                      const HammerLoadingIndicator(size: 44),
                      rsV(context, 16),
                      Text(
                        '문자앱에서 인증을 완료해주세요',
                        style: tt.titleMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      rsV(context, 8),
                      Text(
                        '발송된 문자를 확인하고 인증번호를 전송하면\n자동으로 인증이 완료됩니다.',
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      rsV(context, 16),
                      OutlinedButton(
                        onPressed: () {
                          setState(() => _verificationStarted = false);
                        },
                        child: const Text('취소'),
                      ),
                    ],
                  ),
                ),
              ],

              rsV(context, 24),

              // 안내 사항
              AppInsetTile(
                borderRadius: BorderRadius.circular(8),
                padding: EdgeInsets.all(context.rsi(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: context.rsi(18),
                          color: cs.primary,
                        ),
                        rsH(context, 8),
                        Text(
                          '인증 안내',
                          style: tt.labelLarge?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    rsV(context, 8),
                    Text(
                      '• 인증 문자가 발송되면 문자앱으로 이동합니다.\n'
                      '• 발송된 문자 내용에 따라 인증번호를 회신해주세요.\n'
                      '• 인증이 완료되면 자동으로 등록됩니다.\n'
                      '• 인증은 5분 이내에 완료해야 합니다.',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
