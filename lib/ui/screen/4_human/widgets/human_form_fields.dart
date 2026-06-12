import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/ui/screen/2_add/work_role_presets.dart';
import 'package:w0001/ui/screen/4_human/widgets/human_number_formatter.dart';
import 'package:w0001/util/responsive_layout.dart';

class HumanEditorFormFields extends ConsumerWidget {
  const HumanEditorFormFields({super.key, required this.vm});

  final WorkerViewModel vm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final formRole =
        ref.watch(workerProvider.select((s) => s.humanFormWorkRole));
    final r = formRole;
    final showCustomRoleField =
        r == '직접입력' || (r != null && !isWorkRoleInPresetList(r));

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
                  onPressed: vm.refreshAction,
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
            Text(
              '역할 (인건비 기본값)',
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
                  for (var i = 0; i < kWorkRolePresets.length; i++) ...[
                    if (i > 0) SizedBox(width: context.rsi(6)),
                    FilterChip(
                      showCheckmark: false,
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rsi(4),
                      ),
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        kWorkRolePresets[i],
                        style: tt.labelSmall,
                      ),
                      selected: kWorkRolePresets[i] == '직접입력'
                          ? (r == '직접입력' ||
                              (r != null && !isWorkRoleInPresetList(r)))
                          : formRole == kWorkRolePresets[i],
                      onSelected: (_) =>
                          vm.humanFormSelectWorkRole(kWorkRolePresets[i]),
                    ),
                  ],
                ],
              ),
            ),
            if (showCustomRoleField) ...[
              SizedBox(height: context.rsi(8)),
              TextField(
                controller: vm.workerRoleCustomController,
                style: tt.bodyMedium,
                decoration: _decoration(context, '역할 직접 입력'),
              ),
            ],
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
    return TextField(
      maxLines: maxLines,
      minLines: maxLines > 1 ? 1 : null,
      controller: controller,
      style: tt.bodyMedium,
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
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
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
