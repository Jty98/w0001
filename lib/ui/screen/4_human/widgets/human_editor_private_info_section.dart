import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/human_private_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/user_private_providers.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/widget/admin_sensitive_info_row.dart';
import 'package:w0001/util/auth_dio_user_message.dart';
import 'package:w0001/util/human_contact_display.dart';
import 'package:w0001/util/phone_number_format.dart';
import 'package:w0001/util/resident_registration_format.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 인력 수정 다이얼로그 — 마스킹 + reveal (회원관리 세무정보 UI와 동일 패턴).
class HumanEditorPrivateInfoSection extends ConsumerStatefulWidget {
  const HumanEditorPrivateInfoSection({
    super.key,
    required this.human,
    this.onRrnRevealed,
    this.onManualPhoneRevealed,
  });

  final HumanModel human;
  final ValueChanged<String>? onRrnRevealed;
  final ValueChanged<String>? onManualPhoneRevealed;

  @override
  ConsumerState<HumanEditorPrivateInfoSection> createState() =>
      _HumanEditorPrivateInfoSectionState();
}

class _HumanEditorPrivateInfoSectionState
    extends ConsumerState<HumanEditorPrivateInfoSection> {
  HumanPrivateRead? _masked;
  Object? _loadError;
  var _loading = false;
  var _revealingRrn = false;
  var _revealingLinkedPhone = false;
  var _revealingManualPhone = false;
  String? _revealedRrn;
  String? _revealedLinkedPhone;
  String? _revealedManualPhone;

  int? get _hid => widget.human.hid;

  String? get _linkedUid {
    final uid = widget.human.uid?.trim();
    if (uid == null || uid.isEmpty) return null;
    return uid;
  }

  bool get _canReveal =>
      ref
          .read(authSessionProvider)
          .asData
          ?.value
          ?.role
          .canRevealWorkerPrivateInfo ==
      true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void didUpdateWidget(HumanEditorPrivateInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.human.hid != widget.human.hid) {
      _masked = null;
      _revealedRrn = null;
      _revealedLinkedPhone = null;
      _revealedManualPhone = null;
      _loadError = null;
      Future.microtask(_load);
    }
  }

  Future<void> _load() async {
    final hid = _hid;
    if (hid == null || hid <= 0) return;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await ref.read(humanUseCaseProvider).getHumanPrivate(hid);
      if (!mounted) return;
      setState(() {
        _masked = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _masked = HumanPrivateRead.fromHumanFields(
          hnumber: widget.human.hnumber,
          hphone: widget.human.hphone,
          linkedPhone: widget.human.linkedPhone,
        );
        _loadError = null;
        _loading = false;
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _revealRrn() async {
    final hid = _hid;
    if (hid == null || !_canReveal || _revealingRrn) return;

    setState(() => _revealingRrn = true);
    try {
      final value = await _revealRrnValue(hid);
      if (!mounted) return;
      final formatted = formatResidentRegistrationDisplay(value);
      setState(() => _revealedRrn = formatted);
      widget.onRrnRevealed?.call(formatted);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = dioAuthRelatedUserMessage(e);
      _toast(msg.trim().isNotEmpty ? msg : '주민등록번호 조회에 실패했습니다.');
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    } finally {
      if (mounted) setState(() => _revealingRrn = false);
    }
  }

  Future<String> _revealRrnValue(int hid) async {
    final uid = _linkedUid;
    if (uid != null) {
      return ref.read(userPrivateUseCaseProvider).revealWorkerRrn(
            uid: uid,
            reason: '관리자 조회',
          );
    }
    return ref.read(humanUseCaseProvider).revealHumanRrn(
          hid: hid,
          reason: '관리자 조회',
        );
  }

  Future<void> _revealLinkedPhone() async {
    final hid = _hid;
    if (hid == null || !_canReveal || _revealingLinkedPhone) return;

    setState(() => _revealingLinkedPhone = true);
    try {
      final value = await _revealLinkedPhoneValue(hid);
      if (!mounted) return;
      final formatted =
          isMaskedPhone(value) ? value : formatKoreanMobilePhoneDisplay(value);
      setState(() => _revealedLinkedPhone = formatted);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = dioAuthRelatedUserMessage(e);
      _toast(msg.trim().isNotEmpty ? msg : '인증 연락처 조회에 실패했습니다.');
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    } finally {
      if (mounted) setState(() => _revealingLinkedPhone = false);
    }
  }

  Future<String> _revealLinkedPhoneValue(int hid) async {
    final uid = _linkedUid;
    if (uid != null) {
      try {
        return await ref.read(userPrivateUseCaseProvider).revealWorkerPhone(
              uid: uid,
              reason: '관리자 조회',
            );
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }
    return ref.read(humanUseCaseProvider).revealHumanLinkedPhone(
          hid: hid,
          reason: '관리자 조회',
        );
  }

  Future<void> _revealManualPhone() async {
    final hid = _hid;
    if (hid == null || !_canReveal || _revealingManualPhone) return;

    setState(() => _revealingManualPhone = true);
    try {
      final value = await ref.read(humanUseCaseProvider).revealHumanHphone(
            hid: hid,
            reason: '관리자 조회',
          );
      if (!mounted) return;
      final formatted = formatKoreanMobilePhoneDisplay(value);
      setState(() => _revealedManualPhone = formatted);
      widget.onManualPhoneRevealed?.call(formatted);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = dioAuthRelatedUserMessage(e);
      _toast(msg.trim().isNotEmpty ? msg : '등록 연락처 조회에 실패했습니다.');
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    } finally {
      if (mounted) setState(() => _revealingManualPhone = false);
    }
  }

  Widget _sensitiveRow(
    BuildContext context, {
    required String label,
    required String masked,
    required String? revealed,
    required bool canRevealField,
    required bool revealing,
    required VoidCallback? onReveal,
  }) {
    final display = revealed ?? masked;
    return AdminSensitiveInfoRow(
      label: label,
      display: display,
      isRevealed: revealed != null,
      canReveal: canRevealField && _canReveal,
      revealing: revealing,
      onReveal: revealed == null ? onReveal : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hid = _hid;
    if (hid == null || hid <= 0) return const SizedBox.shrink();

    if (_loading) {
      return Skeletonizer(
        enabled: true,
        child: _content(
          context,
          private: HumanPrivateRead.fromHumanFields(
            hnumber: '930101-*******',
            hphone: '010-****-1234',
            linkedPhone: '010-****-5678',
          ),
        ),
      );
    }

    if (_loadError != null) {
      final cs = Theme.of(context).colorScheme;
      final tt = Theme.of(context).textTheme;
      return Material(
        color: cs.errorContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(context.rsi(14)),
        child: Padding(
          padding: EdgeInsets.all(context.rsi(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '개인정보를 불러오지 못했습니다.',
                style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
              ),
              SizedBox(height: context.rsi(8)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('다시 시도'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final private = _masked;
    if (private == null) return const SizedBox.shrink();
    return _content(context, private: private);
  }

  Widget _content(BuildContext context, {required HumanPrivateRead private}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasAny =
        private.hasRrn || private.hasHphone || private.hasLinkedPhone;

    return AppInsetCard(
      padding: EdgeInsets.all(context.rsi(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: context.rs(20), color: cs.primary),
              SizedBox(width: context.rsi(8)),
              Text(
                '개인정보',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (!hasAny) ...[
            SizedBox(height: context.rsi(10)),
            Text(
              '등록된 개인정보가 없습니다.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ] else ...[
            SizedBox(height: context.rsi(12)),
            _sensitiveRow(
              context,
              label: '주민등록번호',
              masked: private.hasRrn ? (private.rrnMasked ?? '등록됨') : '미등록',
              revealed: _revealedRrn,
              canRevealField: private.hasRrn,
              revealing: _revealingRrn,
              onReveal: _revealRrn,
            ),
            if (private.hasLinkedPhone)
              _sensitiveRow(
                context,
                label: kHumanVerifiedPhoneLabel,
                masked: private.linkedPhoneMasked ?? '등록됨',
                revealed: _revealedLinkedPhone,
                canRevealField: true,
                revealing: _revealingLinkedPhone,
                onReveal: _revealLinkedPhone,
              ),
            _sensitiveRow(
              context,
              label: kHumanManualPhoneLabel,
              masked:
                  private.hasHphone ? (private.hphoneMasked ?? '등록됨') : '미등록',
              revealed: _revealedManualPhone,
              canRevealField: private.hasHphone,
              revealing: _revealingManualPhone,
              onReveal: _revealManualPhone,
            ),
          ],
        ],
      ),
    );
  }
}
