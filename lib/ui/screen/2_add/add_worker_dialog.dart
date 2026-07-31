import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/ui/screen/2_add/work_role_presets.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/keyboard_aware.dart';
import 'package:w0001/ui/widget/round_text_field.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/app_text_field.dart';

class AddWorkerDialog extends ConsumerStatefulWidget {
  const AddWorkerDialog({super.key});

  @override
  ConsumerState<AddWorkerDialog> createState() => _AddWorkerDialogState();
}

class _AddWorkerDialogState extends ConsumerState<AddWorkerDialog> {
  String? _dialogRole;
  late final TextEditingController _dialogCustomRoleController;

  /// Human.hdefaultRole 및 인건비 탭에 반영할 문자열(직접입력이면 입력값, 프리셋이면 라벨).
  String _resolvedRoleToPersist() {
    if (_dialogRole == null) return '';
    if (_dialogRole == '직접입력') {
      return _dialogCustomRoleController.text.trim();
    }
    return _dialogRole!;
  }

  @override
  void initState() {
    super.initState();
    _dialogCustomRoleController = TextEditingController();
  }

  @override
  void dispose() {
    _dialogCustomRoleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.read(addCostProvider.notifier);
    final alertText = ref.watch(addCostProvider).alertText;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          maxWidth: MediaQuery.sizeOf(context).width * 0.92,
        ),
        child: KeyboardAwareScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(24),
            vertical: context.rsi(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: context.rsi(8),
                  bottom: context.rsi(12),
                ),
                child: Text(
                  '사람 추가',
                  textAlign: TextAlign.center,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              RoundTextField(
                controller: vm.hNameController,
                onChanged: (value) => vm.clearWorkerDialogAlert(),
                labelText: '이름 (필수)',
              ),
              SizedBox(height: context.rsi(5)),
              RoundTextField(
                controller: vm.hNumController,
                onChanged: (value) => vm.clearWorkerDialogAlert(),
                labelText: '주민등록번호(선택)',
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: context.rsi(5)),
              AddTextField(
                height: context.rs(66),
                witdh: MediaQuery.sizeOf(context).width,
                tController: vm.hDailyWageController,
                labelText: '일 인건비(선택·추가 시 금액 기본값)',
                keyboardType: TextInputType.number,
                isPrice: true,
                onSubmitted: (value) => vm.clearWorkerDialogAlert(),
                readOnly: false,
              ),
              SizedBox(height: context.rsi(10)),
              Text(
                '역할 (선택)',
                style: tt.labelLarge,
              ),
              SizedBox(height: context.rsi(6)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < kWorkRolePresets.length; i++) ...[
                      if (i > 0) SizedBox(width: context.rsi(6)),
                      ChoiceChip(
                        label: Text(
                          kWorkRolePresets[i],
                          style: tt.labelLarge,
                        ),
                        selected: _dialogRole == kWorkRolePresets[i],
                        onSelected: (_) => setState(() {
                          _dialogRole = kWorkRolePresets[i];
                          if (kWorkRolePresets[i] != '직접입력') {
                            _dialogCustomRoleController.clear();
                          }
                        }),
                      ),
                    ],
                  ],
                ),
              ),
              if (_dialogRole == '직접입력') ...[
                SizedBox(height: context.rsi(8)),
                AppTextField(
                  controller: _dialogCustomRoleController,
                  style: tt.bodyMedium,
                  decoration: InputDecoration(
                    hintText: '역할 직접 입력',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.rsi(10)),
                    ),
                  ),
                ),
              ],
              SizedBox(height: context.rsi(5)),
              RoundTextField(
                controller: vm.hMemoController,
                onChanged: (value) => vm.clearWorkerDialogAlert(),
                labelText: '메모 (선택)',
                height: context.rs(120),
                maxLines: 3,
                maxLength: 50,
              ),
              Text(
                alertText,
                style: tt.bodyMedium?.copyWith(color: cs.error),
              ),
              SizedBox(height: context.rsi(10)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(
                      '취소',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                  SizedBox(width: context.rsi(20)),
                  TextButton(
                    onPressed: () async {
                      vm.clearWorkerDialogAlert();
                      final persistedRole = _resolvedRoleToPersist();
                      final ok =
                          await vm.insertWorker(hdefaultRole: persistedRole);
                      if (!ok || !context.mounted) return;
                      if (context.mounted) {
                        context.pop();
                      }
                    },
                    child: const Text('확인'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
