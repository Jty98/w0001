import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/presentation/viewmodel/terms_providers.dart';
import 'package:w0001/ui/screen/0_auth/widgets/terms_detail_sheet.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 회원가입 — 약관 동의 카드.
class WorkerSignupTermsSection extends ConsumerStatefulWidget {
  const WorkerSignupTermsSection({
    super.key,
    required this.onAgreementsChanged,
    this.showTitle = true,
  });

  final void Function(List<TermAgreementInput> agreements, bool allRequiredOk)
      onAgreementsChanged;
  final bool showTitle;

  @override
  ConsumerState<WorkerSignupTermsSection> createState() =>
      _WorkerSignupTermsSectionState();
}

class _WorkerSignupTermsSectionState
    extends ConsumerState<WorkerSignupTermsSection> {
  final _agreedIds = <int>{};
  var _loadingDetailId = 0;

  void _emit(List<TermSummary> terms) {
    final required = terms.where((t) => t.required).toList(growable: false);
    final requiredOk = required.isEmpty ||
        required.every((t) => _agreedIds.contains(t.id));
    final agreements = terms
        .where((t) => _agreedIds.contains(t.id))
        .map(
          (t) => TermAgreementInput(termId: t.id, version: t.version),
        )
        .toList(growable: false);
    widget.onAgreementsChanged(agreements, requiredOk);
  }

  void _toggleTerm(TermSummary term, List<TermSummary> terms, bool? value) {
    setState(() {
      if (value == true) {
        _agreedIds.add(term.id);
      } else {
        _agreedIds.remove(term.id);
      }
    });
    _emit(terms);
  }

  void _toggleAll(List<TermSummary> terms, bool? value) {
    setState(() {
      if (value == true) {
        _agreedIds.addAll(terms.map((t) => t.id));
      } else {
        _agreedIds.clear();
      }
    });
    _emit(terms);
  }

  bool _allChecked(List<TermSummary> terms) =>
      terms.isNotEmpty && terms.every((t) => _agreedIds.contains(t.id));

  bool? _allCheckboxValue(List<TermSummary> terms) {
    if (terms.isEmpty) return false;
    if (_allChecked(terms)) return true;
    if (_agreedIds.isEmpty) return false;
    return null;
  }

  Future<void> _openDetail(TermSummary term) async {
    if (_loadingDetailId == term.id) return;
    setState(() => _loadingDetailId = term.id);
    try {
      final detail = await ref.read(termsUseCaseProvider).getTermDetail(term.id);
      if (!mounted) return;
      await showTermsDetailSheet(context, detail: detail);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('약관을 불러오지 못했습니다. ($e)')),
      );
    } finally {
      if (mounted) setState(() => _loadingDetailId = 0);
    }
  }

  Widget _termRow(
    BuildContext context,
    TermSummary term,
    List<TermSummary> terms,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final loading = _loadingDetailId == term.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(context.rs(10)),
        onTap: () => _toggleTerm(term, terms, !_agreedIds.contains(term.id)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(4),
            vertical: context.rsi(8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: context.rs(24),
                height: context.rs(24),
                child: Checkbox(
                  value: _agreedIds.contains(term.id),
                  onChanged: (v) => _toggleTerm(term, terms, v),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              SizedBox(width: context.rsi(8)),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                    children: [
                      if (term.required)
                        TextSpan(
                          text: '[필수] ',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      TextSpan(
                        text: term.displayTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: loading ? null : () => _openDetail(term),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: context.rsi(8)),
                  minimumSize: Size(0, context.rs(32)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: loading
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final asyncTerms = ref.watch(signupTermsProvider);

    return asyncTerms.when(
      loading: () => Skeletonizer(
        enabled: true,
        child: _termsCard(
          context,
          child: Column(
            children: [
              for (var i = 0; i < 2; i++) ...[
                if (i > 0) Divider(height: 1, color: cs.outlineVariant),
                ListTile(
                  leading: Checkbox(value: false, onChanged: null),
                  title: Text('약관 제목 ${i + 1}'),
                  trailing: const Text('전문'),
                ),
              ],
            ],
          ),
        ),
      ),
      error: (e, _) => _termsCard(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '약관을 불러오지 못했습니다.',
              style: tt.bodyMedium?.copyWith(color: cs.error),
            ),
            SizedBox(height: context.rsi(10)),
            OutlinedButton(
              onPressed: () => ref.invalidate(signupTermsProvider),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
      data: (terms) {
        if (terms.isEmpty) {
          return _termsCard(
            context,
            child: Text(
              '등록된 약관이 없습니다.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          );
        }

        return _termsCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: cs.primaryContainer.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(context.rs(10)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(context.rs(10)),
                  onTap: () => _toggleAll(terms, !_allChecked(terms)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rsi(10),
                      vertical: context.rsi(10),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: context.rs(24),
                          height: context.rs(24),
                          child: Checkbox(
                            value: _allCheckboxValue(terms),
                            tristate: true,
                            onChanged: (v) => _toggleAll(terms, v ?? false),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        SizedBox(width: context.rsi(8)),
                        Text(
                          '약관 전체 동의',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: context.rsi(6)),
              for (var i = 0; i < terms.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                  ),
                _termRow(context, terms[i], terms),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _termsCard(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle) ...[
          Text(
            '약관 동의',
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: context.rsi(10)),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(context.rs(14)),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(12),
              context.rsi(10),
              context.rsi(8),
              context.rsi(10),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
