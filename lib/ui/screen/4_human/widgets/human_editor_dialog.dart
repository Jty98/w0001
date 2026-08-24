import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/ui/screen/4_human/widgets/human_form_fields.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/responsive_layout.dart';

Future<bool> _confirmDiscardHumanEditor(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('저장하지 않고 나갈까요?'),
      content: const Text('변경한 내용이 저장되지 않습니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('계속 수정'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('나가기'),
        ),
      ],
    ),
  );
  return result == true;
}

/// 인력 등록·수정 다이얼로그. [listIndex]/[editHuman]이 없으면 신규 비회원 등록.
/// 저장 성공 시 저장된 [HumanModel], 취소·실패 시 null.
Future<HumanModel?> showHumanEditorDialog({
  required BuildContext context,
  required WidgetRef ref,
  int? listIndex,
  HumanModel? editHuman,
}) async {
  final vm = ref.read(workerProvider.notifier);
  final isEdit = editHuman != null || (listIndex != null && listIndex >= 0);
  final editTarget = editHuman ?? vm.humanEditorSeed;
  final canDeleteNonMember =
      isEdit && editTarget != null && humanIsNonMember(editTarget);

  return showDialog<HumanModel?>(
    context: context,
    builder: (dialogCtx) {
      var isSaving = false;

      Future<void> tryClose() async {
        if (isSaving || !dialogCtx.mounted) return;
        if (vm.isHumanEditorFormDirty()) {
          final discard = await _confirmDiscardHumanEditor(dialogCtx);
          if (!discard || !dialogCtx.mounted) return;
        }
        Navigator.of(dialogCtx).pop();
        vm.cancelHumanEditorForm();
      }

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop || isSaving) return;
              tryClose();
            },
            child: Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: dialogCtx.rsi(20),
                vertical: dialogCtx.rsi(24),
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
                        dialogCtx.rsi(20),
                        dialogCtx.rsi(16),
                        dialogCtx.rsi(8),
                        0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isEdit ? '인력 수정' : '비회원 인력 등록',
                              style: Theme.of(dialogCtx)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: isSaving ? null : tryClose,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          dialogCtx.rsi(20),
                          dialogCtx.rsi(8),
                          dialogCtx.rsi(20),
                          dialogCtx.rsi(8),
                        ),
                        child: HumanEditorFormFields(
                          key: ValueKey(
                            vm.humanEditorSeed?.hid ?? 'new-human',
                          ),
                          vm: vm,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        dialogCtx.rsi(20),
                        dialogCtx.rsi(8),
                        dialogCtx.rsi(20),
                        dialogCtx.rsi(20),
                      ),
                      child: Row(
                        children: [
                          if (canDeleteNonMember)
                            TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () {
                                      showDialog<void>(
                                        context: dialogCtx,
                                        builder: (confirmCtx) => deleteDialog(
                                          content:
                                              '${editTarget.hname} 님을 삭제할까요?',
                                          onPressed: () async {
                                            setDialogState(
                                              () => isSaving = true,
                                            );
                                            try {
                                              await vm.deleteNonMemberWorker(
                                                listIndex: listIndex,
                                                human: editTarget,
                                              );
                                              await FetchData.onDataChanged(
                                                DataChangeEvent.humanSaved,
                                              );
                                              if (confirmCtx.mounted) {
                                                Navigator.of(confirmCtx).pop();
                                              }
                                              if (dialogCtx.mounted) {
                                                Navigator.of(dialogCtx).pop();
                                                vm.cancelHumanEditorForm();
                                              }
                                            } finally {
                                              if (dialogCtx.mounted) {
                                                setDialogState(
                                                  () => isSaving = false,
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      );
                                    },
                              child: Text(
                                '삭제',
                                style: TextStyle(
                                  color: Theme.of(dialogCtx).colorScheme.error,
                                ),
                              ),
                            ),
                          if (isEdit)
                            TextButton(
                              onPressed: isSaving ? null : tryClose,
                              child: const Text('취소'),
                            ),
                          if (isEdit) SizedBox(width: dialogCtx.rsi(8)),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      setDialogState(() => isSaving = true);
                                      try {
                                        final saved =
                                            await vm.editButtonAction(dialogCtx);
                                        if (saved == null) return;
                                        if (dialogCtx.mounted) {
                                          Navigator.of(dialogCtx).pop(saved);
                                          vm.cancelHumanEditorForm();
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        }
                                      } finally {
                                        if (dialogCtx.mounted) {
                                          setDialogState(
                                              () => isSaving = false);
                                        }
                                      }
                                    },
                              icon: isSaving
                                  ? SizedBox(
                                      width: dialogCtx.rs(18),
                                      height: dialogCtx.rs(18),
                                      child: const HammerLoadingIndicator(
                                          size: 18),
                                    )
                                  : Icon(
                                      isEdit
                                          ? Icons.save_rounded
                                          : Icons.person_add_alt_1_rounded,
                                    ),
                              label: Text(
                                isSaving
                                    ? (isEdit ? '저장 중…' : '등록 중…')
                                    : (isEdit ? '수정 저장' : '등록하기'),
                              ),
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
