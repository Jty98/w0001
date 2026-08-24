import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_skills_editor.dart';
import 'package:w0001/ui/screen/4_human/widgets/human_editor_private_info_section.dart';
import 'package:w0001/ui/screen/4_human/widgets/human_number_formatter.dart';
import 'package:w0001/theme/app_input_styles.dart';
import 'package:w0001/util/career_input.dart';
import 'package:w0001/util/human_contact_display.dart';
import 'package:w0001/util/phone_number_format.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/app_text_field.dart';
import 'package:w0001/ui/widget/worker_profile/worker_career_field.dart';

class HumanEditorFormFields extends ConsumerStatefulWidget {
  const HumanEditorFormFields({super.key, required this.vm});

  final WorkerViewModel vm;

  @override
  ConsumerState<HumanEditorFormFields> createState() =>
      _HumanEditorFormFieldsState();
}

class _HumanEditorFormFieldsState extends ConsumerState<HumanEditorFormFields> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSkillsEditor());
  }

  void _syncSkillsEditor() {
    if (!mounted) return;
    widget.vm.syncHumanSkillsEditorIfNeeded();
    if (widget.vm.hasPendingSkillsEditorLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncSkillsEditor());
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final siteRank =
        ref.watch(workerProvider.select((s) => s.humanFormWorkerRank));
    final careerYears =
        ref.watch(workerProvider.select((s) => s.humanFormCareerYears));
    final editHuman = vm.humanEditorSeed;
    final isEdit = editHuman?.hid != null && editHuman!.hid! > 0;
    final selectedChipColor = cs.primaryContainer;
    final selectedLabelColor = cs.onPrimaryContainer;
    final unselectedChipColor = cs.surfaceContainerHighest;
    final unselectedLabelColor = cs.onSurfaceVariant;

    return Material(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rsi(16)),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.rsi(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: context.rs(20),
                  color: cs.primary,
                ),
                SizedBox(width: context.rsi(8)),
                Text(
                  '기본 정보',
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: vm.resetHumanEditorFormInputs,
                  child: Text(
                    '입력 초기화',
                    style: tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.rsi(12)),
            _field(
              context,
              vm.workerNameController,
              '이름',
              TextInputType.text,
              1,
            ),
            if (isEdit) ...[
              SizedBox(height: context.rsi(14)),
              HumanEditorPrivateInfoSection(
                human: editHuman,
                onRrnRevealed: (value) => vm.workerNumController.text = value,
                onManualPhoneRevealed: (value) =>
                    vm.workerPhoneController.text = value,
              ),
              SizedBox(height: context.rsi(14)),
              Text(
                '정보 수정',
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              SizedBox(height: context.rsi(8)),
            ],
            SizedBox(height: context.rsi(8)),
            _field(
              context,
              vm.workerNumController,
              '주민등록번호',
              TextInputType.number,
              1,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
                HumanNumberFormatter(),
              ],
            ),
            SizedBox(height: context.rsi(8)),
            _field(
              context,
              vm.workerDailyWageController,
              '일당',
              TextInputType.number,
              1,
              useWonCommaFormat: true,
            ),
            SizedBox(height: context.rsi(14)),
            _field(
              context,
              vm.workerPhoneController,
              kHumanManualPhoneLabel,
              TextInputType.phone,
              1,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
                KoreanMobilePhoneFormatter(),
              ],
            ),
            SizedBox(height: context.rsi(14)),
            Text(
              '현장 역할',
              style: tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
            SizedBox(height: context.rsi(8)),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    showCheckmark: true,
                    checkmarkColor: selectedLabelColor,
                    selectedColor: selectedChipColor,
                    backgroundColor: unselectedChipColor,
                    side: BorderSide(
                      color: (siteRank == null || siteRank.isEmpty)
                          ? cs.primary.withValues(alpha: 0.72)
                          : cs.outlineVariant,
                      width: (siteRank == null || siteRank.isEmpty) ? 1.4 : 1.0,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: context.rsi(4)),
                    visualDensity: VisualDensity.standard,
                    label: Text(
                      '미선택',
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: (siteRank == null || siteRank.isEmpty)
                            ? selectedLabelColor
                            : unselectedLabelColor,
                      ),
                    ),
                    selected: siteRank == null || siteRank.isEmpty,
                    onSelected: (_) => vm.humanFormSelectWorkerRank(null),
                  ),
                  for (final rank in kWorkerRankOptions) ...[
                    SizedBox(width: context.rsi(6)),
                    FilterChip(
                      showCheckmark: true,
                      checkmarkColor: selectedLabelColor,
                      selectedColor: selectedChipColor,
                      backgroundColor: unselectedChipColor,
                      side: BorderSide(
                        color: siteRank == rank
                            ? cs.primary.withValues(alpha: 0.72)
                            : cs.outlineVariant,
                        width: siteRank == rank ? 1.4 : 1.0,
                      ),
                      padding: EdgeInsets.symmetric(horizontal: context.rsi(4)),
                      visualDensity: VisualDensity.standard,
                      label: Text(
                        rank,
                        style: tt.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: siteRank == rank
                              ? selectedLabelColor
                              : unselectedLabelColor,
                        ),
                      ),
                      selected: siteRank == rank,
                      onSelected: (_) => vm.humanFormSelectWorkerRank(rank),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: context.rsi(16)),
            WorkerCareerField(
              career: careerYears != null
                  ? CareerInputUtils.formatYears(careerYears)
                  : (editHuman?.career ?? ''),
              readOnlyUntilEdit: isEdit,
              compact: true,
              onChanged: (value) => vm.humanFormSelectCareerYears(
                CareerInputUtils.parseYears(value),
              ),
            ),
            SizedBox(height: context.rsi(16)),
            WorkerSkillsEditor(
              key: vm.humanSkillsEditorKey,
              compact: true,
              initialHuman: vm.humanEditorSeed,
              readOnlyUntilEdit: isEdit,
            ),
            SizedBox(height: context.rsi(8)),
            _field(
              context,
              vm.workerMemoController,
              '메모 (선택)',
              TextInputType.text,
              3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    BuildContext context,
    TextEditingController controller,
    String label,
    TextInputType keyboardType,
    int maxLines, {
    bool useWonCommaFormat = false,
    List<TextInputFormatter>? formatters,
  }) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return AppTextField(
      maxLines: maxLines,
      minLines: maxLines > 1 ? 1 : null,
      controller: controller,
      style: AppInputStyles.fieldText(context),
      decoration: _decoration(context, label).copyWith(
        suffixText: useWonCommaFormat ? '원' : null,
        suffixStyle: tt.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
      ),
      keyboardType: keyboardType,
      inputFormatters: formatters ??
          (keyboardType == TextInputType.number && useWonCommaFormat
              ? [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyTextInputFormatter.currency(
                    decimalDigits: 0,
                    symbol: '',
                  ),
                  LengthLimitingTextInputFormatter(22),
                ]
              : null),
    );
  }

  InputDecoration _decoration(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.rsi(12)),
      borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.65)),
    );
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: cs.appMutedFill,
      contentPadding: EdgeInsets.symmetric(
        horizontal: context.rsi(12),
        vertical: context.rsi(10),
      ),
      labelStyle: tt.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(context.rsi(12)),
        borderSide: BorderSide(color: cs.primary, width: 1.4),
      ),
    );
  }
}
