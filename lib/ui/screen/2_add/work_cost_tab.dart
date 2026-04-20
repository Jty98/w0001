import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/ui/screen/2_add/add_worker_dialog.dart';
import 'package:w0001/ui/screen/2_add/place_recent_workers_sheet.dart';
import 'package:w0001/ui/screen/2_add/work_role_presets.dart';
import 'package:w0001/ui/widget/date_card_widget.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';

class WorkCostTab extends ConsumerStatefulWidget {
  const WorkCostTab({super.key});

  @override
  ConsumerState<WorkCostTab> createState() => _WorkCostTabState();
}

class _WorkCostTabState extends ConsumerState<WorkCostTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final n = ref.read(addCostProvider.notifier);
      n.syncNonPresetWorkRoleToCustomField();
      n.refreshPlaceRecentWorkers();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AddCostState>(addCostProvider, (prev, next) {
      if (prev?.selectedWorkRole != next.selectedWorkRole) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(addCostProvider.notifier)
              .syncNonPresetWorkRoleToCustomField();
        });
      }
    });

    final state = ref.watch(addCostProvider);
    final vm = ref.read(addCostProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SelectDateButton(),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: humanDropdownSearch(context, ref)),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                width: 48,
                child: OutlinedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AddWorkerDialog(),
                  ).then((_) => vm.clearDialogText()),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Icon(
                    Icons.person_add_alt_1,
                    color: Colors.blue[700],
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _placeRecentWorkersSection(context, ref),
          Expanded(
            child: state.workCostList.isEmpty
                ? Center(
                    child: Text(
                      '추가한 인원이 없습니다.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.only(top: 6, bottom: 10),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: state.workCostList.length,
                    itemBuilder: (context, index) {
                      final originalIndex =
                          state.workCostList.length - 1 - index;
                      final item = state.workCostList[originalIndex];
                      return _WorkCostProfileCard(
                        item: item,
                        onEdit: () => _showEditPendingWorkCostDialog(
                          context,
                          ref,
                          originalIndex,
                          item,
                        ),
                        onDelete: () => _confirmDeleteWorkCost(
                          context,
                          ref,
                          originalIndex,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

Widget _placeRecentWorkersSection(BuildContext context, WidgetRef ref) {
  final state = ref.watch(addCostProvider);
  final vm = ref.read(addCostProvider.notifier);
  final cs = Theme.of(context).colorScheme;
  const radius = BorderRadius.all(Radius.circular(12));
  final recent = state.placeRecentWorkers;

  if (state.selectedPlace == null) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: radius,
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.place_outlined, size: 26, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '현장을 먼저 선택하면 이전에 투입했던 인원이 여기 표시됩니다.',
                  style: smallStyle.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  if (recent.isEmpty) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: radius,
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.history_rounded, size: 26, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '이 현장에 기록된 인원이 없습니다. 위에서 선택하면 최근 목록에 쌓입니다.',
                  style: smallStyle.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: radius,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '이 현장에서 일했던 인원',
                      style: categoryStyle.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: () => showPlaceRecentWorkersSheet(
                      context: context,
                      ref: ref,
                    ),
                    child: Text('전체보기(${recent.length})'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 기존 UX 유지: 가로 스크롤 칩 목록
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < recent.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      ActionChip(
                        label: Text(recent[i].hname),
                        onPressed: () =>
                            vm.tapPlaceRecentWorker(context, recent[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _confirmDeleteWorkCost(
  BuildContext context,
  WidgetRef ref,
  int originalIndex,
) async {
  final vm = ref.read(addCostProvider.notifier);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('삭제'),
      content: const Text('이 항목을 목록에서 삭제할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('삭제', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await vm.deleteWorkList(originalIndex);
  }
}

/// 목록에 넣기 전 항목의 역할 문자열 → 다이얼로그 초기 칩 선택값.
String? _dialogInitialRoleForEdit(
  String wrole,
  TextEditingController custom,
) {
  if (wrole.isEmpty) return null;
  final fixed = kWorkRolePresets.where((e) => e != '직접입력').toSet();
  if (fixed.contains(wrole)) return wrole;
  custom.text = wrole;
  return '직접입력';
}

Future<void> _showEditPendingWorkCostDialog(
  BuildContext context,
  WidgetRef ref,
  int originalIndex,
  WorkCostModel item,
) async {
  final vm = ref.read(addCostProvider.notifier);
  final nameController = TextEditingController(text: item.hname ?? '');
  final priceController = TextEditingController(text: item.wprice.toString());
  final customRoleController = TextEditingController();
  var dialogRole = _dialogInitialRoleForEdit(item.wrole, customRoleController);

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final showCustomRole = dialogRole == '직접입력';
          return AlertDialog(
            title: const Text('항목 수정'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '이름',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '역할',
                      style: Theme.of(ctx).textTheme.labelLarge,
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
                              selected: dialogRole == kWorkRolePresets[i],
                              onSelected: (_) => setLocal(() {
                                dialogRole = kWorkRolePresets[i];
                                if (kWorkRolePresets[i] != '직접입력') {
                                  customRoleController.clear();
                                }
                              }),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (showCustomRole) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customRoleController,
                        decoration: const InputDecoration(
                          hintText: '역할 직접 입력',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '금액',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('이름을 입력해 주세요.')),
                    );
                    return;
                  }
                  var priceStr =
                      priceController.text.trim().replaceAll(RegExp(r'[,원\s]'), '');
                  final price = int.tryParse(priceStr);
                  if (price == null || price < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('올바른 금액을 입력해 주세요.')),
                    );
                    return;
                  }

                  String wrole;
                  if (dialogRole == null) {
                    wrole = '';
                  } else if (dialogRole == '직접입력') {
                    wrole = customRoleController.text.trim();
                  } else {
                    wrole = dialogRole!;
                  }

                  vm.updateWorkCostAt(
                    originalIndex,
                    item.copyWith(
                      hname: name,
                      wprice: price,
                      wrole: wrole,
                    ),
                  );
                  Navigator.of(ctx).pop();
                },
                child: const Text('저장'),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  priceController.dispose();
  customRoleController.dispose();
}

class _WorkCostProfileCard extends StatelessWidget {
  const _WorkCostProfileCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkCostModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = item.hname ?? '';
    final initial =
        name.isNotEmpty ? String.fromCharCode(name.runes.first) : '?';

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        child: Text(
                          initial,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.wrole.isEmpty ? '—' : item.wrole,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blueGrey[700],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        getPrice(price: item.wprice),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -10,
            right: -10,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              iconSize: 14,
              onPressed: onDelete,
              icon: const Icon(Icons.close, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

Widget humanDropdownSearch(BuildContext context, WidgetRef ref) {
  final state = ref.watch(addCostProvider);
  final vm = ref.read(addCostProvider.notifier);

  return SizedBox(
    height: 48,
    child: DropdownSearch<HumanModel>.multiSelection(
      asyncItems: (text) => ref.read(humanUseCaseProvider).getAllWorkers(),
      itemAsString: (item) => item.hname,
      compareFn: (a, b) => a.hid != null && b.hid != null && a.hid == b.hid,
      onChanged: (values) async {
        if (ref.read(addCostProvider).selectedPlace == null) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('현장을 먼저 선택해주세요.')),
          );
          return;
        }
        await vm.workersChangeAction(values);
      },
      // multiSelection 기본은 선택된 항목을 파란 Chip 형태로 필드에 노출한다.
      // 이 화면에서는 Summary 카드에서만 보여주므로, 필드는 "N명 선택됨" 텍스트로만 표시.
      dropdownBuilder: (context, selected) {
        final n = (selected as List<HumanModel>?)?.length ?? 0;
        if (n == 0) {
          return const Text(
            '사람 선택',
            style: TextStyle(fontSize: 14, color: Colors.black54),
            overflow: TextOverflow.ellipsis,
          );
        }
        return Text(
          '$n명 선택됨',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        );
      },
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelStyle: const TextStyle(fontSize: 14),
          hintStyle: const TextStyle(fontSize: 14),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          hintText: '사람 선택',
        ),
      ),
      selectedItems: state.selectedWorkers,
      popupProps: PopupPropsMultiSelection.menu(
        emptyBuilder: (context, searchEntry) => const Center(
          child: Text('검색 결과 없음'),
        ),
        showSearchBox: true,
        showSelectedItems: false,
        searchFieldProps: TextFieldProps(
          controller: TextEditingController(),
          decoration: const InputDecoration(
            constraints: BoxConstraints(maxHeight: 40),
            hintText: '사람을 검색하세요.',
            isDense: true,
            hintStyle: TextStyle(fontSize: 13),
            labelStyle: TextStyle(fontSize: 13),
            border: OutlineInputBorder(gapPadding: 100),
          ),
        ),
        searchDelay: Duration.zero,
      ),
    ),
  );
}
