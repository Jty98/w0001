import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/data/model/user_private_models.dart';
import 'package:w0001/presentation/viewmodel/terms_providers.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_tax_terms_agreement.dart';
import 'package:w0001/ui/widget/resident_registration_split_field.dart';
import 'package:w0001/ui/widget/round_text_field.dart';
import 'package:w0001/util/responsive_layout.dart';

const kWorkerPrivateBankNames = <String>[
  '국민은행',
  '신한은행',
  '우리은행',
  '하나은행',
  '기업은행',
  'NH농협은행',
  '카카오뱅크',
  '케이뱅크',
  'SC제일은행',
  '부산은행',
  '대구은행',
  '경남은행',
  '광주은행',
  '제주은행',
];

/// 작업자·관리자 공통 세무·정산 입력 폼 (작업자 설정 화면 UI 기준).
class WorkerPrivateInfoFormBody extends ConsumerWidget {
  const WorkerPrivateInfoFormBody({
    super.key,
    required this.isEditMode,
    required this.rrnFrontController,
    required this.rrnBackController,
    required this.bankAccountController,
    required this.bankOwnerController,
    required this.bankNameController,
    required this.onChanged,
    this.rrnFrontFocusNode,
    this.rrnBackFocusNode,
    this.private,
    this.rrnErrorText,
    this.showTaxTerms = true,
    this.onTaxTermChanged,
    this.rrnViewTrailing,
    this.bankViewTrailing,
    this.rrnLabelText,
  });

  final bool isEditMode;
  final UserPrivateRead? private;
  final TextEditingController rrnFrontController;
  final TextEditingController rrnBackController;
  final TextEditingController bankAccountController;
  final TextEditingController bankOwnerController;
  final TextEditingController bankNameController;
  final FocusNode? rrnFrontFocusNode;
  final FocusNode? rrnBackFocusNode;
  final ValueChanged<String> onChanged;
  final String? rrnErrorText;
  final bool showTaxTerms;
  final void Function(bool agreed, TermSummary? term)? onTaxTermChanged;
  final Widget? rrnViewTrailing;
  final Widget? bankViewTrailing;
  final String? rrnLabelText;

  void _setBankName(TextEditingController controller, String value) {
    controller.text = value;
    controller.selection = TextSelection.collapsed(offset: value.length);
    onChanged(value);
  }

  String _formatAgreementDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return trimmed;
    final local = parsed.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$y년 $m월 $d일 $h시 $mi분 $s초';
  }

  Widget _taxConsentHistory(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(workerTaxAgreementsProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (agreements) {
        if (agreements.isEmpty) return const SizedBox.shrink();
        final latest = agreements.first;
        final at = latest.agreedAt?.trim() ?? '';
        final agreedAt = at.isNotEmpty ? _formatAgreementDate(at) : '';
        return Padding(
          padding: EdgeInsets.only(top: context.rsi(12)),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(context.rsi(12)),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(context.rs(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '세무 동의 이력',
                  style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: context.rsi(4)),
                Text(
                  '버전 ${latest.version}'
                  '${agreedAt.isNotEmpty ? '\n동의일 $agreedAt' : ''}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hasRrn = private?.hasRrn == true;
    final fieldHeight = context.rsi(54);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResidentRegistrationSplitField(
          frontController: rrnFrontController,
          backController: rrnBackController,
          frontFocusNode: rrnFrontFocusNode,
          backFocusNode: rrnBackFocusNode,
          labelText:
              rrnLabelText ?? ((isEditMode && hasRrn) ? '주민등록번호 변경' : '주민등록번호'),
          enabled: isEditMode,
          showClearButton: isEditMode,
          height: fieldHeight,
          errorText: rrnErrorText,
          viewModeTrailing: !isEditMode ? rrnViewTrailing : null,
          onChanged: onChanged,
        ),
        SizedBox(height: context.rsi(16)),
        RoundTextField(
          controller: bankAccountController,
          keyboardType: TextInputType.number,
          labelText: '계좌번호',
          hintText: isEditMode ? '하이픈(-) 없이 입력하세요.' : null,
          height: fieldHeight,
          showClearButton: isEditMode,
          enabled: isEditMode,
          suffixIcon: !isEditMode ? bankViewTrailing : null,
          suffixTrailingWidth:
              bankViewTrailing != null ? context.rsi(36) : null,
          inputFormatters: isEditMode
              ? [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(20),
                ]
              : null,
          onChanged: onChanged,
        ),
        SizedBox(height: context.rsi(16)),
        RoundTextField(
          controller: bankOwnerController,
          keyboardType: TextInputType.name,
          labelText: '예금주',
          height: fieldHeight,
          showClearButton: isEditMode,
          enabled: isEditMode,
          onChanged: onChanged,
        ),
        SizedBox(height: context.rsi(16)),
        if (isEditMode)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RoundTextField(
                  controller: bankNameController,
                  labelText: '은행명',
                  height: fieldHeight,
                  showClearButton: true,
                  enabled: true,
                  onChanged: onChanged,
                ),
              ),
              SizedBox(width: context.rsi(8)),
              SizedBox(
                height: context.rsi(48),
                width: context.rsi(72),
                child: Material(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.rs(10)),
                    side: BorderSide(color: cs.outline),
                  ),
                  child: PopupMenuButton<String>(
                    tooltip: '은행 선택',
                    padding: EdgeInsets.zero,
                    icon: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          size: context.rsi(18),
                        ),
                        Icon(Icons.arrow_drop_down, size: context.rsi(16)),
                      ],
                    ),
                    itemBuilder: (_) => kWorkerPrivateBankNames
                        .map(
                          (bank) => PopupMenuItem(
                            value: bank,
                            child: Text(bank),
                          ),
                        )
                        .toList(),
                    onSelected: (bank) =>
                        _setBankName(bankNameController, bank),
                  ),
                ),
              ),
            ],
          )
        else
          RoundTextField(
            controller: bankNameController,
            labelText: '은행명',
            height: fieldHeight,
            enabled: false,
            onChanged: (_) {},
          ),
        if (isEditMode && showTaxTerms) ...[
          SizedBox(height: context.rsi(24)),
          Text(
            '약관 동의',
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: context.rsi(14),
            ),
          ),
          SizedBox(height: context.rsi(12)),
          Builder(
            builder: (context) {
              final taxAgreements =
                  ref.watch(workerTaxAgreementsProvider).asData?.value ?? [];
              final hasTaxAgreement = taxAgreements.isNotEmpty;
              final agreedToTax =
                  private?.workerTaxTermAgreed == true || hasTaxAgreement;

              return WorkerTaxTermsAgreement(
                alreadyAgreed: agreedToTax,
                onChanged: onTaxTermChanged ?? (_, __) {},
              );
            },
          ),
          _taxConsentHistory(context, ref),
        ] else if (!isEditMode && private?.workerTaxTermAgreed == true) ...[
          SizedBox(height: context.rsi(12)),
          Text(
            '세무정보 수집·이용 동의 완료',
            style: tt.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
