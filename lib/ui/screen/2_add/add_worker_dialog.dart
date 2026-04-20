import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/ui/screen/2_add/work_role_presets.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/round_text_field.dart';
import 'package:w0001/util/text_style.dart';

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

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          maxWidth: MediaQuery.sizeOf(context).width * 0.92,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 12),
                child: Text(
                  '사람 추가',
                  textAlign: TextAlign.center,
                  style: bigStyle,
                ),
              ),
              RoundTextField(
                controller: vm.hNameController,
                onChanged: (value) => vm.clearWorkerDialogAlert(),
                labelText: '이름 (필수)',
              ),
              const SizedBox(height: 5),
              RoundTextField(
                controller: vm.hNumController,
                onChanged: (value) => vm.clearWorkerDialogAlert(),
                labelText: '주민등록번호(선택)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 5),
              AddTextField(
                height: 66,
                witdh: MediaQuery.sizeOf(context).width,
                tController: vm.hDailyWageController,
                labelText: '일 인건비(선택·추가 시 금액 기본값)',
                keyboardType: TextInputType.number,
                isPrice: true,
                onSubmitted: (value) => vm.clearWorkerDialogAlert(),
                readOnly: false,
              ),
              const SizedBox(height: 10),
              Text(
                '역할 (선택)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < kWorkRolePresets.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text(
                          kWorkRolePresets[i],
                          style: const TextStyle(fontSize: 13),
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
                const SizedBox(height: 8),
                TextField(
                  controller: _dialogCustomRoleController,
                  decoration: InputDecoration(
                    hintText: '역할 직접 입력',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 5),
              RoundTextField(
                controller: vm.hMemoController,
                onChanged: (value) => vm.clearWorkerDialogAlert(),
                labelText: '메모 (선택)',
                height: 120,
                maxLines: 3,
                maxLength: 50,
              ),
              Text(
                alertText,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      '취소',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 20),
                  TextButton(
                    onPressed: () async {
                      vm.clearWorkerDialogAlert();
                      final persistedRole = _resolvedRoleToPersist();
                      final ok =
                          await vm.insertWorker(hdefaultRole: persistedRole);
                      if (!ok || !context.mounted) return;
                      vm.applyDefaultRoleFromPersistedString(persistedRole);
                      if (context.mounted) {
                        Navigator.of(context).pop();
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
