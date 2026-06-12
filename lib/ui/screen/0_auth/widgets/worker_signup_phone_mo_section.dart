import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/phone_verification_models.dart';
import 'package:w0001/presentation/viewmodel/phone_mo_verification_providers.dart';
import 'package:w0001/ui/widget/round_text_field.dart';
import 'package:w0001/util/auth_dio_user_message.dart';
import 'package:w0001/util/phone_number_format.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 작업자 가입 — 옥토모 MO 휴대폰 인증 섹션.
class WorkerSignupPhoneMoSection extends ConsumerStatefulWidget {
  const WorkerSignupPhoneMoSection({
    super.key,
    required this.onVerifiedChanged,
    this.showHeader = true,
  });

  final void Function(String? phone, String? verificationToken) onVerifiedChanged;
  final bool showHeader;

  @override
  ConsumerState<WorkerSignupPhoneMoSection> createState() =>
      _WorkerSignupPhoneMoSectionState();
}

class _WorkerSignupPhoneMoSectionState
    extends ConsumerState<WorkerSignupPhoneMoSection> {
  final _phoneController = TextEditingController();
  PhoneMoStartResponse? _session;
  var _starting = false;
  var _polling = false;
  var _pollGeneration = 0;
  String? _verifiedPhone;
  String? _verificationToken;

  bool get isVerified =>
      _verifiedPhone != null && _verificationToken != null;

  @override
  void dispose() {
    _pollGeneration++;
    _phoneController.dispose();
    super.dispose();
  }

  void _notifyParent() {
    widget.onVerifiedChanged(_verifiedPhone, _verificationToken);
  }

  void _resetVerification({bool notify = true}) {
    _pollGeneration++;
    _session = null;
    _verifiedPhone = null;
    _verificationToken = null;
    _polling = false;
    if (notify) _notifyParent();
    if (mounted) setState(() {});
  }

  void _onPhoneChanged(String _) {
    if (_verifiedPhone != null || _session != null) {
      _resetVerification();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _copyToClipboard(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label을(를) 복사했습니다.')),
    );
  }

  Future<void> _startVerification() async {
    if (_starting || _polling) return;
    final phone = _phoneController.text.trim();
    final formatMsg = koreanMobilePhoneFormatMessage(phone);
    if (formatMsg != null) {
      _toast(formatMsg);
      return;
    }

    setState(() {
      _starting = true;
      _session = null;
      _verifiedPhone = null;
      _verificationToken = null;
    });
    _notifyParent();

    try {
      final session = await ref
          .read(phoneMoVerificationUseCaseProvider)
          .start(phone);
      if (!mounted) return;
      setState(() => _session = session);
    } on DioException catch (e) {
      if (!mounted) return;
      _toast(_dioMessage(e, '인증코드 발급에 실패했습니다.'));
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _openSmsAndPoll() async {
    final session = _session;
    if (session == null || _polling) return;

    final opened = await ref.read(phoneMoVerificationUseCaseProvider).openSmsComposer(
          moNumber: session.moNumber,
          body: session.smsBody,
        );
    if (!opened && mounted) {
      _toast('문자 앱을 열 수 없습니다. 번호와 코드를 복사해 직접 보내 주세요.');
    }
    unawaited(_poll());
  }

  Future<void> _poll() async {
    if (_polling || _session == null) return;
    final gen = ++_pollGeneration;
    final phone = normalizeKoreanMobilePhone(_phoneController.text);
    final timeoutSec = _session!.expiresInSeconds.clamp(60, 600);

    setState(() => _polling = true);
    try {
      final token = await ref.read(phoneMoVerificationUseCaseProvider).waitUntilVerified(
            phone,
            timeout: Duration(seconds: timeoutSec),
            shouldContinue: () => mounted && gen == _pollGeneration,
          );
      if (!mounted || gen != _pollGeneration) return;
      setState(() {
        _verifiedPhone = phone;
        _verificationToken = token;
        _polling = false;
      });
      _notifyParent();
      _toast('휴대폰 인증이 완료되었습니다.');
    } on DioException catch (e) {
      if (!mounted || gen != _pollGeneration) return;
      _toast(_dioMessage(e, '인증 확인에 실패했습니다.'));
      setState(() => _polling = false);
    } catch (e) {
      if (!mounted || gen != _pollGeneration) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      _toast(msg);
      if (msg.contains('만료')) {
        setState(() => _session = null);
      }
      setState(() => _polling = false);
    }
  }

  String _dioMessage(DioException e, String fallback) {
    final msg = dioAuthRelatedUserMessage(e);
    return msg.trim().isNotEmpty ? msg : fallback;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String step) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: context.rs(26),
          height: context.rs(26),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(context.rs(8)),
          ),
          child: Text(
            step,
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
        SizedBox(width: context.rsi(10)),
        Text(
          title,
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _copyChip(
    BuildContext context, {
    required String label,
    required String value,
    required TextStyle? valueStyle,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(context.rs(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(context.rs(12)),
        onTap: () => _copyToClipboard(label, value),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(14),
            vertical: context.rsi(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    SizedBox(height: context.rsi(4)),
                    Text(value, style: valueStyle),
                  ],
                ),
              ),
              Icon(Icons.copy_rounded, size: context.rs(18), color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final session = _session;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) ...[
          _sectionTitle(context, '휴대폰 인증', '2'),
          SizedBox(height: context.rsi(12)),
        ],
        RoundTextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          labelText: '휴대폰 번호',
          hintText: '010-0000-0000',
          showClearButton: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
            KoreanMobilePhoneFormatter(),
          ],
          onChanged: _onPhoneChanged,
        ),
        if (isVerified) ...[
          SizedBox(height: context.rsi(10)),
          Container(
            padding: EdgeInsets.all(context.rsi(12)),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(context.rs(12)),
              border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_rounded, color: cs.primary, size: context.rs(22)),
                SizedBox(width: context.rsi(10)),
                Expanded(
                  child: Text(
                    '${formatKoreanMobilePhoneDisplay(_verifiedPhone!)} 인증 완료',
                    style: tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _resetVerification,
                  child: const Text('다시 인증'),
                ),
              ],
            ),
          ),
        ] else ...[
          if (session == null) ...[
            SizedBox(height: context.rsi(12)),
            FilledButton(
              onPressed: _starting ? null : _startVerification,
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(context.rs(48)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.rs(12)),
                ),
              ),
              child: _starting
                  ? SizedBox(
                      width: context.rs(22),
                      height: context.rs(22),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Text('인증코드 받기'),
            ),
          ] else ...[
            SizedBox(height: context.rsi(12)),
            Container(
              padding: EdgeInsets.all(context.rsi(14)),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(context.rs(14)),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    session.instructions.isNotEmpty
                        ? session.instructions
                        : '${session.moNumberDisplay} 번호로 인증코드를 문자로 보내주세요.',
                    style: tt.bodyMedium?.copyWith(height: 1.45),
                  ),
                  SizedBox(height: context.rsi(12)),
                  _copyChip(
                    context,
                    label: '문자 받는 번호',
                    value: session.moNumberDisplay,
                    valueStyle: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: context.rsi(8)),
                  _copyChip(
                    context,
                    label: '인증코드 (문자 본문)',
                    value: session.verificationCode,
                    valueStyle: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: cs.primary,
                    ),
                  ),
                  if (session.phoneMasked.isNotEmpty) ...[
                    SizedBox(height: context.rsi(8)),
                    Text(
                      '등록 번호: ${session.phoneMasked}',
                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                  SizedBox(height: context.rsi(14)),
                  FilledButton.icon(
                    onPressed: _polling ? null : _openSmsAndPoll,
                    icon: const Icon(Icons.sms_rounded),
                    label: Text(_polling ? '인증 확인 중…' : '문자 보내기'),
                    style: FilledButton.styleFrom(
                      minimumSize: Size.fromHeight(context.rs(48)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.rs(12)),
                      ),
                    ),
                  ),
                  if (_polling) ...[
                    SizedBox(height: context.rsi(12)),
                    Row(
                      children: [
                        SizedBox(
                          width: context.rs(18),
                          height: context.rs(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        ),
                        SizedBox(width: context.rsi(10)),
                        Expanded(
                          child: Text(
                            '문자 수신을 확인하고 있습니다. 발송 후 잠시만 기다려 주세요.',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: context.rsi(8)),
                  OutlinedButton(
                    onPressed: _starting || _polling ? null : _startVerification,
                    child: const Text('인증코드 다시 받기'),
                  ),
                ],
              ),
            ),
          ],
          if (kDebugMode) ...[
            SizedBox(height: context.rsi(8)),
            OutlinedButton(
              onPressed: () {
                final phone = _phoneController.text.trim();
                final normalized = normalizeKoreanMobilePhone(phone);
                if (normalized.isEmpty || normalized.length < 10) {
                  _toast('우회할 휴대폰 번호를 입력해 주세요.');
                  return;
                }
                setState(() {
                  _verifiedPhone = normalized;
                  _verificationToken = 'debug_bypass_token_$normalized';
                  _session = null;
                });
                _notifyParent();
                _toast('[$normalized] 인증 우회 완료 (디버그)');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.secondary,
                side: BorderSide(color: cs.secondary),
                minimumSize: Size.fromHeight(context.rs(40)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.rs(12)),
                ),
              ),
              child: const Text('인증 우회하기 (디버그)'),
            ),
          ],
        ],
      ],
    );
  }
}
