import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/ui/widget/work_cost_delete_dialog.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/app_text_field.dart';

/// 인력별 인건비 항목 목록.
class WorkCostGroupedListBody extends ConsumerWidget {
  const WorkCostGroupedListBody({
    super.key,
    required this.filteredList,
    required this.listFilter,
    required this.storageScope,
    this.scrollable = false,
  });

  final List<TotalWorkCostModel> filteredList;
  final CompleteState listFilter;
  final String storageScope;
  final bool scrollable;

  static int _compareByDate(TotalWorkCostModel a, TotalWorkCostModel b) {
    final ad = DateTime.tryParse(normalizeToIsoDateString(a.date));
    final bd = DateTime.tryParse(normalizeToIsoDateString(b.date));
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return bd.compareTo(ad);
  }

  static String? _monthKeyFor(TotalWorkCostModel item) {
    final d = DateTime.tryParse(normalizeToIsoDateString(item.date));
    if (d == null) return null;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  static String _monthLabelFor(TotalWorkCostModel item) {
    final d = DateTime.tryParse(normalizeToIsoDateString(item.date));
    if (d == null) return item.date;
    return '${d.year}년 ${d.month}월';
  }

  static List<Object> _rowsWithMonthDividers(List<TotalWorkCostModel> sorted) {
    final rows = <Object>[];
    String? lastMonthKey;
    for (final item in sorted) {
      final monthKey = _monthKeyFor(item) ?? item.date;
      if (monthKey != lastMonthKey) {
        rows.add(_monthLabelFor(item));
        lastMonthKey = monthKey;
      }
      rows.add(item);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(workerProvider.notifier);
    final sorted = [...filteredList]..sort(_compareByDate);
    final rows = _rowsWithMonthDividers(sorted);

    return ListView.builder(
      key: ValueKey<String>('work_cost_flat_$storageScope'),
      padding: EdgeInsets.only(
        top: context.rsi(2),
        bottom: scrollable ? context.rsi(8) : 0,
      ),
      shrinkWrap: !scrollable,
      physics: scrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is String) {
          return _WorkCostMonthDivider(label: row);
        }
        final element = row as TotalWorkCostModel;
        return WorkCostEntryTile(
          element: element,
          listFilter: listFilter,
          onEdit: () => showEditWorkCostPriceDialog(context, ref, element, vm),
        );
      },
    );
  }
}

class _WorkCostMonthDivider extends StatelessWidget {
  const _WorkCostMonthDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final lineColor = cs.outlineVariant.withValues(alpha: 0.65);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rsi(2),
        context.rsi(14),
        context.rsi(2),
        context.rsi(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: lineColor,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.rsi(10)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: lineColor,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkCostEntryTile extends ConsumerWidget {
  const WorkCostEntryTile({
    super.key,
    required this.element,
    required this.listFilter,
    required this.onEdit,
  });

  final TotalWorkCostModel element;
  final CompleteState listFilter;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workerProvider);
    final vm = ref.read(workerProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final isPaid = element.wcomplete == 1;
    final isIncompleteTab = listFilter == CompleteState.incomplete;
    final compact = ResponsiveLayout.isCompact(MediaQuery.sizeOf(context));

    return Slidable(
      startActionPane: isIncompleteTab
          ? null
          : ActionPane(
              motion: const DrawerMotion(),
              extentRatio: compact ? 0.18 : 0.22,
              children: [
                CustomSlidableAction(
                  onPressed: (slidableCtx) async {
                    await vm.updateWComplete(element.wcomplete, element.wid);
                    if (!slidableCtx.mounted) return;
                    await showDialog<void>(
                      context: slidableCtx,
                      builder: (_) => saveDialog(
                        text: isPaid ? '미지급으로 변경되었습니다.' : '지급 완료로 변경되었습니다.',
                      ),
                    );
                  },
                  backgroundColor: isPaid ? cs.primary : cs.tertiary,
                  foregroundColor: isPaid ? cs.onPrimary : cs.onTertiary,
                  padding: EdgeInsets.zero,
                  child: Icon(
                    isPaid
                        ? Icons.autorenew_rounded
                        : Icons.check_circle_rounded,
                    size: 22,
                  ),
                ),
              ],
            ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: compact ? 0.24 : 0.28,
        children: [
          CustomSlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: cs.secondaryContainer,
            foregroundColor: cs.onSecondaryContainer,
            padding: EdgeInsets.zero,
            child: const Icon(Icons.edit_outlined, size: 20),
          ),
          CustomSlidableAction(
            onPressed: (slidableCtx) async {
              final pwdid = await vm.placeWorkDayPwdidFor(element);
              if (!slidableCtx.mounted) return;
              final choice = await showWorkCostDeleteDialog(
                slidableCtx,
                placeName: element.pname,
                workerName: element.hname,
                dateLabel: element.date,
                hasLinkedWorkDay: pwdid != null,
                workrole: element.workrole,
              );
              if (choice == null ||
                  choice == WorkCostDeleteChoice.cancel ||
                  !slidableCtx.mounted) {
                return;
              }
              await vm.deleteWorkCostLinked(
                wid: element.wid,
                pwdid: choice == WorkCostDeleteChoice.costAndWorkDay
                    ? pwdid
                    : null,
              );
            },
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            padding: EdgeInsets.zero,
            child: const Icon(Icons.delete_outline_rounded, size: 20),
          ),
        ],
      ),
      child: Builder(builder: (ctx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          vm.registerSlidable(ctx);
        });
        return Padding(
          padding: EdgeInsets.only(bottom: context.rsi(6)),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: context.rsi(2),
                    top: context.rsi(8),
                  ),
                  child: Checkbox(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: cs.primary, width: 2),
                    value:
                        state.checkboxStates[element.wid]?.isSelected ?? false,
                    onChanged: (_) {
                      ref
                          .read(workerProvider.notifier)
                          .toggleCheckboxState(element.wid);
                    },
                  ),
                ),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.rsi(4),
                          context.rsi(6),
                          context.rsi(8),
                          context.rsi(6),
                        ),
                        child: WorkCostListItemCard(
                          element: element,
                          isTaxApply: state.isTaxApply,
                          isPaid: isPaid,
                          completedAtLabel: element.wcompletedAt != null
                              ? formatWorkCostCompletedAt(element.wcompletedAt!)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class WorkCostListItemCard extends StatelessWidget {
  const WorkCostListItemCard({
    super.key,
    required this.element,
    required this.isTaxApply,
    required this.isPaid,
    this.completedAtLabel,
  });

  final TotalWorkCostModel element;
  final bool isTaxApply;
  final bool isPaid;
  final String? completedAtLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final priceText = getPrice(price: element.price, isTaxApply: isTaxApply);
    final workDate = formatWorkCostWorkDate(element.date);
    final role = element.workrole.trim();

    Widget infoLine(String label, String value, {Color? valueColor}) {
      return Padding(
        padding: EdgeInsets.only(top: context.rsi(3)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: context.rs(62),
              child: Text(
                label,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? cs.onSurface,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(10),
        vertical: context.rsi(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  workDate,
                  style: tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isPaid ? cs.onPrimaryContainer : cs.onSurface,
                  ),
                ),
              ),
              _workCostStatusBadge(context: context, isPaid: isPaid),
              SizedBox(width: context.rsi(8)),
              Text(
                priceText,
                style: tt.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isPaid ? cs.primary : cs.error,
                ),
              ),
            ],
          ),
          infoLine('현장', element.pname),
          if (role.isNotEmpty) infoLine('작업내용', role),
          if (isPaid && completedAtLabel != null)
            infoLine(
              '지급완료',
              completedAtLabel!,
              valueColor: cs.primary,
            ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isPaid
            ? cs.primaryContainer.withValues(alpha: 0.55)
            : cs.surfaceContainerLowest,
      ),
      child: content,
    );
  }
}

Widget _workCostStatusBadge({
  required BuildContext context,
  required bool isPaid,
}) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final label = isPaid ? '지급완료' : '미지급';
  final bg = isPaid ? cs.primary : cs.error;
  final fg = isPaid ? cs.onPrimary : cs.onError;

  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: context.rsi(7),
      vertical: context.rsi(3),
    ),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: tt.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: fg,
        height: 1,
      ),
    ),
  );
}

Future<void> showEditWorkCostPriceDialog(
  BuildContext context,
  WidgetRef ref,
  TotalWorkCostModel element,
  WorkerViewModel vm,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _EditWorkCostPriceDialog(
      element: element,
      vm: vm,
      parentContext: context,
    ),
  );
}

class _EditWorkCostPriceDialog extends StatefulWidget {
  const _EditWorkCostPriceDialog({
    required this.element,
    required this.vm,
    required this.parentContext,
  });

  final TotalWorkCostModel element;
  final WorkerViewModel vm;
  final BuildContext parentContext;

  @override
  State<_EditWorkCostPriceDialog> createState() =>
      _EditWorkCostPriceDialogState();
}

class _EditWorkCostPriceDialogState extends State<_EditWorkCostPriceDialog> {
  late final TextEditingController _priceController;
  late final CurrencyTextInputFormatter _priceFormatter;

  @override
  void initState() {
    super.initState();
    _priceFormatter = CurrencyTextInputFormatter.currency(
      decimalDigits: 0,
      symbol: '',
    );
    _priceController = TextEditingController(
      text: widget.element.price > 0
          ? _priceFormatter.formatDouble(widget.element.price.toDouble())
          : '',
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final priceStr =
        _priceController.text.trim().replaceAll(RegExp(r'[,원\s]'), '');
    final price = int.tryParse(priceStr);
    if (price == null || price < 0) {
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        const SnackBar(content: Text('올바른 금액을 입력해 주세요.')),
      );
      return;
    }

    await widget.vm.updateWorkCostPrice(widget.element.wid, price);
    if (!mounted) return;
    Navigator.of(context).pop();

    if (!widget.parentContext.mounted) return;
    await showDialog<void>(
      context: widget.parentContext,
      builder: (_) => saveDialog(text: '금액이 수정되었습니다.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final role = widget.element.workrole.trim();
    return Dialog(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.rsi(14)),
          color: cs.surface,
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(16),
              context.rsi(14),
              context.rsi(16),
              context.rsi(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '인건비 금액 수정',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: context.rsi(4)),
                Text(
                  '현장/날짜를 확인하고 금액을 수정해 저장하세요.',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: context.rsi(10)),
                _readonlyInfoBox(
                  context: context,
                  title: '현장',
                  value: widget.element.pname,
                ),
                SizedBox(height: context.rsi(8)),
                _readonlyInfoBox(
                  context: context,
                  title: '날짜',
                  value: formatWorkCostWorkDate(widget.element.date),
                ),
                if (role.isNotEmpty) ...[
                  SizedBox(height: context.rsi(8)),
                  _readonlyInfoBox(
                    context: context,
                    title: '작업내용',
                    value: role,
                  ),
                ],
                SizedBox(height: context.rsi(8)),
                AppTextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _priceFormatter,
                    LengthLimitingTextInputFormatter(13),
                  ],
                  decoration: InputDecoration(
                    labelText: '금액',
                    isDense: true,
                    suffixText: '원',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  autofocus: true,
                ),
                SizedBox(height: context.rsi(10)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('취소'),
                      ),
                    ),
                    SizedBox(width: context.rsi(8)),
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
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
    );
  }

  Widget _readonlyInfoBox({
    required BuildContext context,
    required String title,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(context.rsi(10)),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(
        context.rsi(10),
        context.rsi(8),
        context.rsi(10),
        context.rsi(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: context.rsi(2)),
          Text(
            value,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
