import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/ui/screen/4_human/widgets/human_form_fields.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/worker_skills_display.dart';

/// 인력 등록·수정 다이얼로그. [listIndex]가 null이면 신규 등록.
Future<void> showHumanEditorDialog({
  required BuildContext context,
  required WidgetRef ref,
  int? listIndex,
}) async {
  final vm = ref.read(workerProvider.notifier);
  final state = ref.read(workerProvider);
  final isEdit = listIndex != null && listIndex >= 0;
  HumanModel? human;
  if (isEdit && listIndex < state.filteredWorkerList.length) {
    human = state.filteredWorkerList[listIndex];
  }

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(workerProvider);
          final editingHuman = isEdit &&
                  s.selectedIndex >= 0 &&
                  s.selectedIndex < s.filteredWorkerList.length
              ? s.filteredWorkerList[s.selectedIndex]
              : human;

          return PopScope(
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) vm.refreshAction();
            },
            child: Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: context.rsi(20),
              vertical: context.rsi(24),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(dialogCtx).height * 0.88,
                maxWidth: 480,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.rsi(20),
                      context.rsi(16),
                      context.rsi(8),
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEdit ? '인력 수정' : '인력 등록',
                            style: Theme.of(dialogCtx)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            vm.refreshAction();
                            Navigator.of(dialogCtx).pop();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        context.rsi(20),
                        context.rsi(8),
                        context.rsi(20),
                        context.rsi(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HumanEditorFormFields(vm: vm),
                          if (isEdit && editingHuman != null) ...[
                            SizedBox(height: context.rsi(14)),
                            ListenableBuilder(
                              listenable: Listenable.merge([
                                vm.workerRoleCustomController,
                              ]),
                              builder: (_, __) {
                                ref.watch(
                                  workerProvider
                                      .select((s) => s.humanFormWorkRole),
                                );
                                return HumanWorkerSkillsPanel(
                                  human: editingHuman,
                                  formRolePreview:
                                      vm.humanFormPersistedDefaultRole(),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.rsi(20),
                      context.rsi(8),
                      context.rsi(20),
                      context.rsi(20),
                    ),
                    child: Row(
                      children: [
                        if (isEdit)
                          TextButton(
                            onPressed: () {
                              vm.refreshAction();
                              Navigator.of(dialogCtx).pop();
                            },
                            child: const Text('취소'),
                          ),
                        if (isEdit) SizedBox(width: context.rsi(8)),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              await vm.editButtonAction(dialogCtx);
                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop();
                                FocusManager.instance.primaryFocus?.unfocus();
                              }
                            },
                            icon: Icon(
                              isEdit
                                  ? Icons.save_rounded
                                  : Icons.person_add_alt_1_rounded,
                            ),
                            label: Text(isEdit ? '수정 저장' : '등록하기'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          );
        },
      );
    },
  );
}
