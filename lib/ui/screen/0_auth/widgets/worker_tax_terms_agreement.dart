import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/presentation/viewmodel/terms_providers.dart';
import 'package:w0001/presentation/viewmodel/user_private_providers.dart';
import 'package:w0001/ui/screen/0_auth/widgets/terms_detail_sheet.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 세무정보 저장 전 `worker_tax` 약관 동의.
class WorkerTaxTermsAgreement extends ConsumerStatefulWidget {
  const WorkerTaxTermsAgreement({
    super.key,
    required this.alreadyAgreed,
    required this.onChanged,
  });

  final bool alreadyAgreed;
  final void Function(bool agreed, TermSummary? term) onChanged;

  @override
  ConsumerState<WorkerTaxTermsAgreement> createState() =>
      _WorkerTaxTermsAgreementState();
}

class _WorkerTaxTermsAgreementState extends ConsumerState<WorkerTaxTermsAgreement> {
  var _checked = false;
  var _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _checked = widget.alreadyAgreed;
  }

  @override
  void didUpdateWidget(WorkerTaxTermsAgreement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.alreadyAgreed && !_checked) {
      _checked = true;
    }
  }

  void _notify(TermSummary? term) {
    widget.onChanged(_checked || widget.alreadyAgreed, term);
  }

  Future<void> _openDetail(TermSummary term) async {
    if (_loadingDetail) return;
    setState(() => _loadingDetail = true);
    try {
      final detail = await ref.read(termsUseCaseProvider).getTermDetail(term.id);
      if (!mounted) return;
      await showTermsDetailSheet(context, detail: detail);
      if (!widget.alreadyAgreed) {
        setState(() => _checked = true);
        _notify(term);
      }
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final asyncTerm = ref.watch(workerTaxTermProvider);

    return asyncTerm.when(
      loading: () => Skeletonizer(
        enabled: true,
        child: _card(
          context,
          child: const ListTile(
            leading: Checkbox(value: false, onChanged: null),
            title: Text('세무정보 수집·이용 동의'),
            trailing: Text('전문'),
          ),
        ),
      ),
      error: (_, __) => _card(
        context,
        child: Text(
          '약관을 불러오지 못했습니다.',
          style: tt.bodyMedium?.copyWith(color: cs.error),
        ),
      ),
      data: (term) {
        if (term == null) {
          return _card(
            context,
            child: Text(
              '세무정보 약관이 등록되지 않았습니다.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          );
        }

        if (widget.alreadyAgreed) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _notify(term));
          return _card(
            context,
            child: Row(
              children: [
                Icon(Icons.verified_rounded, color: cs.primary, size: context.rs(20)),
                SizedBox(width: context.rsi(10)),
                Expanded(
                  child: Text(
                    '${term.displayTitle} 동의 완료',
                    style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: _loadingDetail ? null : () => _openDetail(term),
                  child: _loadingDetail
                      ? SizedBox(
                          width: context.rs(16),
                          height: context.rs(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        )
                      : const Text('전문'),
                ),
              ],
            ),
          );
        }

        return _card(
          context,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '[필수] ${term.displayTitle}',
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (_checked)
                      Padding(
                        padding: EdgeInsets.only(top: context.rsi(4)),
                        child: Text(
                          '전문을 확인하셨습니다. 저장 시 동의가 완료됩니다.',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _loadingDetail ? null : () => _openDetail(term),
                child: _loadingDetail
                    ? SizedBox(
                        width: context.rs(16),
                        height: context.rs(16),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      )
                    : const Text('전문'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(context.rs(14)),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.rsi(12),
          vertical: context.rsi(10),
        ),
        child: child,
      ),
    );
  }
}
