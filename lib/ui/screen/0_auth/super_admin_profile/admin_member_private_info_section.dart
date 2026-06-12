import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/data/model/user_private_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/user_private_providers.dart';
import 'package:w0001/util/auth_dio_user_message.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 관리자 회원 상세 — 작업자 세무·정산 정보 (마스킹 + reveal).
class AdminMemberPrivateInfoSection extends ConsumerStatefulWidget {
  const AdminMemberPrivateInfoSection({
    super.key,
    required this.workerUid,
  });

  final String workerUid;

  @override
  ConsumerState<AdminMemberPrivateInfoSection> createState() =>
      _AdminMemberPrivateInfoSectionState();
}

class _AdminMemberPrivateInfoSectionState
    extends ConsumerState<AdminMemberPrivateInfoSection> {
  UserPrivateRead? _masked;
  Object? _loadError;
  var _loading = false;
  var _revealingRrn = false;
  var _revealingBank = false;
  String? _revealedRrn;
  String? _revealedBank;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void didUpdateWidget(AdminMemberPrivateInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workerUid != widget.workerUid) {
      _masked = null;
      _revealedRrn = null;
      _revealedBank = null;
      _loadError = null;
      Future.microtask(_load);
    }
  }

  bool get _canReveal =>
      ref.read(authSessionProvider).asData?.value?.role
          .canRevealWorkerPrivateInfo ==
      true;

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await ref
          .read(userPrivateUseCaseProvider)
          .getWorkerPrivate(widget.workerUid);
      if (!mounted) return;
      setState(() {
        _masked = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
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
    if (!_canReveal || _revealingRrn) return;

    setState(() => _revealingRrn = true);
    try {
      final value = await ref.read(userPrivateUseCaseProvider).revealWorkerRrn(
            uid: widget.workerUid,
            reason: '관리자 조회',
          );
      if (!mounted) return;
      setState(() => _revealedRrn = value);
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

  Future<void> _revealBank() async {
    if (!_canReveal || _revealingBank) return;

    setState(() => _revealingBank = true);
    try {
      final value =
          await ref.read(userPrivateUseCaseProvider).revealWorkerBankAccount(
                uid: widget.workerUid,
                reason: '관리자 조회',
              );
      if (!mounted) return;
      setState(() => _revealedBank = value);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = dioAuthRelatedUserMessage(e);
      _toast(msg.trim().isNotEmpty ? msg : '계좌번호 조회에 실패했습니다.');
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    } finally {
      if (mounted) setState(() => _revealingBank = false);
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final display = revealed ?? masked;
    final isRevealed = revealed != null;

    return Padding(
      padding: EdgeInsets.only(bottom: context.rsi(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.rsi(4)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  display,
                  style: tt.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isRevealed ? cs.error : cs.onSurface,
                  ),
                ),
              ),
              if (canRevealField && _canReveal && revealed == null) ...[
                SizedBox(width: context.rsi(8)),
                TextButton(
                  onPressed: revealing ? null : onReveal,
                  child: revealing
                      ? SizedBox(
                          width: context.rs(18),
                          height: context.rs(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        )
                      : const Text('전체 보기'),
                ),
              ],
            ],
          ),
          if (isRevealed)
            Padding(
              padding: EdgeInsets.only(top: context.rsi(2)),
              child: Text(
                '전체 조회됨 · 화면을 닫으면 다시 마스킹됩니다.',
                style: tt.labelSmall?.copyWith(color: cs.error),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_loading) {
      return Skeletonizer(
        enabled: true,
        child: _content(
          context,
          private: const UserPrivateRead(
            rrnMasked: '******-*******',
            bankAccountMasked: '****1234',
            bankOwner: '홍길동',
            bankName: '국민은행',
            hasRrn: true,
            hasBankAccount: true,
          ),
        ),
      );
    }

    if (_loadError != null) {
      return Material(
        color: cs.errorContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(context.rsi(14)),
        child: Padding(
          padding: EdgeInsets.all(context.rsi(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '세무·정산 정보를 불러오지 못했습니다.',
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

  Widget _content(BuildContext context, {required UserPrivateRead private}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasAny = private.hasRrn ||
        private.hasBankAccount ||
        (private.bankOwner?.isNotEmpty ?? false) ||
        (private.bankName?.isNotEmpty ?? false);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.rsi(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: context.rs(20), color: cs.primary),
                SizedBox(width: context.rsi(8)),
                Text(
                  '세무·정산 정보',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (!hasAny) ...[
              SizedBox(height: context.rsi(10)),
              Text(
                '등록된 세무·정산 정보가 없습니다.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ] else ...[
              SizedBox(height: context.rsi(12)),
              _sensitiveRow(
                context,
                label: '주민등록번호',
                masked: private.hasRrn
                    ? (private.rrnMasked ?? '등록됨')
                    : '미등록',
                revealed: _revealedRrn,
                canRevealField: private.hasRrn,
                revealing: _revealingRrn,
                onReveal: _revealRrn,
              ),
              _sensitiveRow(
                context,
                label: '계좌번호',
                masked: private.hasBankAccount
                    ? (private.bankAccountMasked ?? '등록됨')
                    : '미등록',
                revealed: _revealedBank,
                canRevealField: private.hasBankAccount,
                revealing: _revealingBank,
                onReveal: _revealBank,
              ),
              if (private.bankOwner?.isNotEmpty == true)
                _plainRow(context, label: '예금주', value: private.bankOwner!),
              if (private.bankName?.isNotEmpty == true)
                _plainRow(context, label: '은행명', value: private.bankName!),
              if (private.workerTaxTermAgreed)
                Padding(
                  padding: EdgeInsets.only(top: context.rsi(4)),
                  child: Text(
                    '세무정보 수집·이용 동의 완료',
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _plainRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: context.rsi(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: context.rsi(72),
            child: Text(
              label,
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
