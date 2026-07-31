import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/ui/screen/2_add/add_worker_dialog.dart';
import 'package:w0001/ui/screen/2_add/place_recent_workers_sheet.dart';
import 'package:w0001/ui/screen/2_add/work_role_chip_panel.dart';
import 'package:w0001/ui/screen/2_add/work_role_suggestions.dart';
import 'package:w0001/ui/widget/date_card_widget.dart';
import 'package:w0001/ui/widget/keyboard_aware.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/widget/app_text_field.dart';

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
      n.refreshPlaceRecentWorkers();
      n.refreshProcessTasksOnSelectedDay();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addCostProvider);
    final vm = ref.read(addCostProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: ResponsiveLayout.only(context, left: 12, top: 10, right: 12),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SelectDateButton(),
                rsV(context, 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: humanDropdownSearch(context, ref)),
                    rsH(context, 8),
                    SizedBox(
                      height: context.rs(48),
                      width: context.rs(48),
                      child: OutlinedButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => const AddWorkerDialog(),
                        ).then((_) => vm.clearDialogText()),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.rs(12)),
                          ),
                        ),
                        child: Icon(
                          Icons.person_add_alt_1,
                          color: cs.primary,
                          size: context.rsi(22),
                        ),
                      ),
                    ),
                  ],
                ),
                rsV(context, 8),
                _placeRecentWorkersSection(context, ref),
              ],
            ),
          ),
          if (state.workCostList.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  '추가한 인원이 없습니다.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            SliverPadding(
              padding: ResponsiveLayout.only(context, top: 6, bottom: 10),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: context.rsi(6),
                  crossAxisSpacing: context.rsi(6),
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final originalIndex = state.workCostList.length - 1 - index;
                    final item = state.workCostList[originalIndex];
                    return WorkCostProfileCard(
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
                  childCount: state.workCostList.length,
                ),
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
  final recent = state.placeRecentWorkers;

  if (state.selectedPlace == null) {
    return Padding(
      padding: ResponsiveLayout.only(context, bottom: 8),
      child: AppInsetTile(
        padding:
            ResponsiveLayout.symmetric(context, vertical: 14, horizontal: 12),
        child: Row(
          children: [
            Icon(Icons.place_outlined,
                size: context.rsi(26), color: cs.onSurfaceVariant),
            rsH(context, 12),
            Expanded(
              child: Text(
                '현장을 먼저 선택하면 이전에 투입했던 인원이 여기 표시됩니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.3,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  if (recent.isEmpty) {
    return Padding(
      padding: ResponsiveLayout.only(context, bottom: 8),
      child: AppInsetTile(
        padding:
            ResponsiveLayout.symmetric(context, vertical: 14, horizontal: 12),
        child: Row(
          children: [
            Icon(Icons.history_rounded,
                size: context.rsi(26), color: cs.onSurfaceVariant),
            rsH(context, 12),
            Expanded(
              child: Text(
                '이 현장에 기록된 인원이 없습니다. 위에서 선택하면 최근 목록에 쌓입니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.3,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  return Padding(
    padding: ResponsiveLayout.only(context, bottom: 8),
    child: AppInsetCard(
      padding: ResponsiveLayout.only(context,
          left: 12, top: 10, right: 12, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded,
                  size: context.rsi(18), color: cs.onSurfaceVariant),
              rsH(context, 6),
              Expanded(
                child: Text(
                  '이 현장에서 일했던 인원',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < recent.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  GestureDetector(
                    onLongPress: () async {
                      final hid = recent[i].hid;
                      if (hid == null) return;
                      await _confirmDeleteRecentWorker(
                        context,
                        ref,
                        hid,
                        recent[i].hname,
                      );
                    },
                    child: ActionChip(
                      label: Text(recent[i].hname),
                      onPressed: () =>
                          vm.tapPlaceRecentWorker(context, recent[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _confirmDeleteRecentWorker(
  BuildContext context,
  WidgetRef ref,
  int hid,
  String name,
) async {
  final vm = ref.read(addCostProvider.notifier);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('인원 삭제'),
      content: Text('$name 인원을 최근 목록에서 삭제할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            '삭제',
            style: TextStyle(color: Theme.of(ctx).colorScheme.error),
          ),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await vm.deletePlaceRecentWorker(hid);
  }
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
          child: Text(
            '삭제',
            style: TextStyle(color: Theme.of(ctx).colorScheme.error),
          ),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await vm.deleteWorkList(originalIndex);
  }
}

Future<void> _showEditPendingWorkCostDialog(
  BuildContext context,
  WidgetRef ref,
  int originalIndex,
  WorkCostModel item,
) async {
  final vm = ref.read(addCostProvider.notifier);
  final addState = ref.read(addCostProvider);
  final processTasks = addState.processTasksOnSelectDay;
  HumanModel? editHuman;
  for (final w in addState.selectedWorkers) {
    if (w.hid == item.whid) {
      editHuman = w;
      break;
    }
  }
  if (editHuman == null && item.whid != null) {
    try {
      final workers =
          await ref.read(humanUseCaseProvider).getWorkersByHids([item.whid!]);
      if (workers.isNotEmpty) editHuman = workers.first;
    } catch (_) {}
  }
  final workerSkills = workerSkillRoleSuggestions(
    editHuman != null ? [editHuman] : const [],
  );
  final priceFormatter = CurrencyTextInputFormatter.currency(
    decimalDigits: 0,
    symbol: '',
  );
  final nameController = TextEditingController(text: item.hname ?? '');
  final priceController = TextEditingController(
    text: item.wprice > 0
        ? priceFormatter.formatDouble(item.wprice.toDouble())
        : '',
  );
  final customRoleController = TextEditingController();
  final (initChip, customFill) = workRoleInitialSelection(
    item.wrole,
    processTasks: processTasks,
    workerSkills: workerSkills,
  );
  customRoleController.text = customFill;
  var dialogRole = initChip;

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final displayName = item.hname?.trim();
          final cs = Theme.of(ctx).colorScheme;
          final tt = Theme.of(ctx).textTheme;
          final selectedDay = DateTime.tryParse(item.wdate) ??
              ref.read(addCostProvider).selectDay;
          final dateOnly =
              DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
          return Dialog(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ctx.rs(14)),
                color: cs.surface,
                border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.45)),
              ),
              child: Padding(
                padding: ResponsiveLayout.only(
                  ctx,
                  left: 16,
                  top: 14,
                  right: 16,
                  bottom: 12,
                ),
                child: SizedBox(
                  width: double.maxFinite,
                  child: KeyboardAwareScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          displayName?.isNotEmpty == true
                              ? displayName!
                              : '인건비 항목 수정',
                          style: tt.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        rsV(ctx, 2),
                        Text(
                          '날짜는 연동 안정성을 위해 변경할 수 없습니다.',
                          style: tt.labelSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        rsV(ctx, 10),
                        Container(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          padding: ResponsiveLayout.all(ctx, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                formatDateTimeWeekDayToString(dateOnly),
                                style: tt.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              rsV(ctx, 6),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        AppInsetCard(
                          padding: ResponsiveLayout.all(ctx, 12),
                          child: WorkRoleChipPanel(
                            dense: true,
                            showApplyHint: false,
                            selectedWorkRole: dialogRole,
                            processTasks: processTasks,
                            workerSkills: workerSkills,
                            processTasksLoading: addState.processTasksLoading,
                            customRoleController: customRoleController,
                            onSelectRole: (role) => setLocal(() {
                              dialogRole = role;
                              if (role != '직접입력') {
                                customRoleController.clear();
                              }
                            }),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          scrollPadding: keyboardScrollPadding(ctx),
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: '이름',
                            isDense: true,
                            filled: true,
                            fillColor: cs.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        AppTextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            priceFormatter,
                            LengthLimitingTextInputFormatter(13),
                          ],
                          decoration: InputDecoration(
                            labelText: '금액',
                            isDense: true,
                            filled: true,
                            fillColor: cs.surface,
                            suffixText: '원',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('취소'),
                              ),
                            ),
                            SizedBox(width: ctx.rsi(8)),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  final name = nameController.text.trim();
                                  if (name.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('이름을 입력해 주세요.')),
                                    );
                                    return;
                                  }
                                  final priceStr = priceController.text
                                      .trim()
                                      .replaceAll(RegExp(r'[,원\s]'), '');
                                  final price = int.tryParse(priceStr);
                                  if (price == null || price < 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('올바른 금액을 입력해 주세요.')),
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
                                child: const Text('수정 저장'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  nameController.dispose();
  priceController.dispose();
  customRoleController.dispose();
}

class WorkCostProfileCard extends StatelessWidget {
  const WorkCostProfileCard({
    super.key,
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppInsetTile(
      borderRadius: BorderRadius.circular(context.rs(10)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onEdit,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.rsi(6),
                    context.rsi(8),
                    context.rsi(6),
                    context.rsi(6),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                name,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: tt.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  height: 1.12,
                                ),
                              ),
                              SizedBox(height: context.rsi(2)),
                              Text(
                                item.wrole.isEmpty ? '오늘 한 일 입력' : item.wrole,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: tt.labelSmall?.copyWith(
                                  fontSize: context.rs(10),
                                  fontWeight: item.wrole.isEmpty
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: item.wrole.isEmpty
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                  height: 1.15,
                                ),
                              ),
                              SizedBox(height: context.rsi(3)),
                              Text(
                                getPrice(price: item.wprice),
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: tt.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.05,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: context.rsi(22),
                minHeight: context.rsi(22),
              ),
              iconSize: context.rsi(15),
              onPressed: onDelete,
              icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
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
  final tt = Theme.of(context).textTheme;
  final cs = Theme.of(context).colorScheme;

  return SizedBox(
    height: context.rs(48),
    child: DropdownSearch<HumanModel>.multiSelection(
      asyncItems: (text) {
        final q = text.trim();
        final uc = ref.read(humanUseCaseProvider);
        if (q.isEmpty) {
          return uc.getAllWorkers();
        }
        return uc.searchWorkers(q: q);
      },
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
          return Text(
            '사람 선택',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          );
        }
        return Text(
          '$n명 선택됨',
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        );
      },
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelStyle: tt.bodyMedium,
          hintStyle: tt.bodyMedium,
          isDense: true,
          contentPadding: ResponsiveLayout.symmetric(
            context,
            horizontal: 12,
            vertical: 12,
          ),
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
          decoration: InputDecoration(
            constraints: BoxConstraints(maxHeight: context.rs(40)),
            hintText: '사람을 검색하세요.',
            isDense: true,
            hintStyle: tt.bodySmall,
            labelStyle: tt.bodySmall,
            border: OutlineInputBorder(gapPadding: 100),
          ),
        ),
        searchDelay: Duration.zero,
      ),
    ),
  );
}
