import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/place_dropdown_model.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/ui/screen/4_human/widgets/work_cost_process_meta.dart';
import 'package:w0001/theme/app_colors.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/widget/segment_widget.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 미지급·지급 건수·금액 요약 카드.
class WorkCostCountAmountSummary extends ConsumerWidget {
  const WorkCostCountAmountSummary({
    super.key,
    required this.unpaidCount,
    required this.unpaidAmount,
    required this.paidCount,
    required this.paidAmount,
    this.isTaxApply = false,
    this.compact = true,
    this.selectionScope,
  });

  final int unpaidCount;
  final int unpaidAmount;
  final int paidCount;
  final int paidAmount;
  final bool isTaxApply;
  final bool compact;

  /// 항목 화면에서 전달 시 탭으로 해당 그룹 체크박스 전체 선택·해제.
  final List<TotalWorkCostModel>? selectionScope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(workerProvider);
    final vm = ref.read(workerProvider.notifier);
    final scope = selectionScope;
    final unpaidActive = scope != null && vm.areAllUnpaidSelectedIn(scope);
    final paidActive = scope != null && vm.areAllPaidSelectedIn(scope);
    final canSelectUnpaid = scope != null && unpaidCount > 0;
    final canSelectPaid = scope != null && paidCount > 0;

    return Row(
      children: [
        Expanded(
          child: _WorkCostPaymentStatBox(
            label: '미지급',
            count: unpaidCount,
            amount: getPrice(price: unpaidAmount, isTaxApply: isTaxApply),
            accent: Theme.of(context).colorScheme.error,
            compact: compact,
            active: unpaidActive,
            onTap: canSelectUnpaid
                ? () => vm.toggleSelectAllUnpaidIn(scope)
                : null,
          ),
        ),
        SizedBox(width: context.rsi(compact ? 6 : 8)),
        Expanded(
          child: _WorkCostPaymentStatBox(
            label: '지급',
            count: paidCount,
            amount: getPrice(price: paidAmount, isTaxApply: isTaxApply),
            accent: Theme.of(context).colorScheme.primary,
            compact: compact,
            active: paidActive,
            onTap: canSelectPaid ? () => vm.toggleSelectAllPaidIn(scope) : null,
          ),
        ),
      ],
    );
  }
}

class _WorkCostPaymentStatBox extends StatelessWidget {
  const _WorkCostPaymentStatBox({
    required this.label,
    required this.count,
    required this.amount,
    required this.accent,
    required this.compact,
    this.onTap,
    this.active = false,
  });

  final String label;
  final int count;
  final String amount;
  final Color accent;
  final bool compact;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final labelStyle = (compact ? tt.labelSmall : tt.labelMedium)?.copyWith(
      fontWeight: FontWeight.w700,
      color: accent,
      height: 1.0,
    );
    final countStyle = (compact ? tt.titleSmall : tt.titleMedium)?.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface,
      height: 1.0,
    );
    final amountStyle = (compact ? tt.labelSmall : tt.labelMedium)?.copyWith(
      fontWeight: FontWeight.w700,
      color: accent.withValues(alpha: 0.92),
      height: 1.1,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.rs(compact ? 8 : 10)),
        child: AppInsetTile(
          borderRadius: BorderRadius.circular(context.rs(compact ? 8 : 10)),
          backgroundColor: active
              ? accent.withValues(alpha: 0.16)
              : accent.withValues(alpha: 0.08),
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(compact ? 8 : 10),
            vertical: context.rsi(compact ? 7 : 9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(label, style: labelStyle),
                  if (onTap != null) ...[
                    const Spacer(),
                    Icon(
                      active
                          ? Icons.check_circle_rounded
                          : Icons.touch_app_outlined,
                      size: context.rs(compact ? 13 : 15),
                      color: accent.withValues(alpha: active ? 0.9 : 0.45),
                    ),
                  ],
                ],
              ),
              SizedBox(height: context.rsi(compact ? 4 : 5)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$count', style: countStyle),
                  Text(
                    '건',
                    style: countStyle?.copyWith(
                      fontSize: (countStyle.fontSize ?? 14) * 0.82,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(amount, style: amountStyle),
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

class WorkCostHumanAppBarTitle extends StatelessWidget {
  const WorkCostHumanAppBarTitle({
    super.key,
    required this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: tt.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        height: 1.1,
      ),
    );
  }

  /// [splitLayout]일 때 앱바 [bottom]에 넣을 배지·부제 영역.
  static Widget? bottomSection({
    required BuildContext context,
    HumanModel? human,
    Widget? subtitle,
  }) {
    if (human == null && subtitle == null) return null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rsi(16),
        0,
        context.rsi(8),
        context.rsi(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (human != null) WorkCostHumanBadges(human: human, appBar: true),
          if (human != null && subtitle != null)
            SizedBox(height: context.rsi(4)),
          if (subtitle != null) subtitle,
        ],
      ),
    );
  }
}

class WorkCostPeriodToggleBar extends ConsumerWidget {
  const WorkCostPeriodToggleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workerProvider);
    final vm = ref.read(workerProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final isThisMonth = state.dayState == DayTpye.month;
    final toggleW = (MediaQuery.sizeOf(context).width - context.rs(28)) / 2;

    return SizedBox(
      height: context.rs(30),
      child: ToggleButtons(
        borderColor: cs.outlineVariant,
        selectedBorderColor: cs.outlineVariant,
        borderWidth: 1,
        borderRadius: BorderRadius.circular(5),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
        isSelected: [!isThisMonth, isThisMonth],
        onPressed: (index) {
          vm.selectToggleButton(index, context).then((_) {
            vm.closeAllSliders();
            vm.collapseAllExpansionTiles();
          });
        },
        children: [
          toggleWidget(
            width: toggleW,
            child: const Text('기간 선택'),
            icon: Icon(
              Icons.calendar_month,
              color: !isThisMonth ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),
          toggleWidget(
            width: toggleW,
            child: const Text('이번 달'),
          ),
        ],
      ),
    );
  }
}

class WorkCostFilterBar extends ConsumerWidget {
  const WorkCostFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workerProvider);
    final vm = ref.read(workerProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final segStyle = Theme.of(context).textTheme.labelMedium;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CupertinoSlidingSegmentedControl<CompleteState>(
          groupValue: state.completeState,
          children: {
            CompleteState.whole: Text('전체', style: segStyle),
            CompleteState.incomplete: Text('미지급', style: segStyle),
          },
          onValueChanged: vm.completeStateValueChanged,
        ),
        CupertinoSlidingSegmentedControl<TaxState>(
          groupValue: state.taxState,
          thumbColor: state.isTaxApply
              ? cs.errorContainer.withValues(alpha: 0.65)
              : cs.primaryContainer.withValues(alpha: 0.65),
          children: {
            TaxState.taxOff: Text('세전', style: segStyle),
            TaxState.taxOn: Text('세후', style: segStyle),
          },
          onValueChanged: vm.taxStateValueChanged,
        ),
      ],
    );
  }
}

/// 현장 필터 — 인건비 목록·인력 상세 공통. 높이 최소화.
class WorkCostCompactPlaceFilter extends ConsumerStatefulWidget {
  const WorkCostCompactPlaceFilter({super.key, this.uniqueHumanKey});

  /// null이면 기간 전체 현장, 값이 있으면 해당 인력 항목에서 추출.
  final String? uniqueHumanKey;

  @override
  ConsumerState<WorkCostCompactPlaceFilter> createState() =>
      _WorkCostCompactPlaceFilterState();
}

class _WorkCostCompactPlaceFilterState
    extends ConsumerState<WorkCostCompactPlaceFilter> {
  @override
  void initState() {
    super.initState();
    if (widget.uniqueHumanKey == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          ref.read(workerProvider.notifier).ensureWorkCostPeriodPlacesLoaded(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workerProvider);
    ref.watch(workerProvider.select((s) => s.workCostPlaceOptionsNonce));
    final vm = ref.read(workerProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final options = widget.uniqueHumanKey == null
        ? vm.workCostPeriodPlaceOptions()
        : vm.workCostPlaceOptionsForHuman(widget.uniqueHumanKey!);
    final selectedPid = state.workCostPlacePid;
    final loadingPlaces =
        widget.uniqueHumanKey == null && vm.isWorkCostPeriodPlacesLoading;
    final hasPlaces = options.length > 1;
    final canPick = hasPlaces && !loadingPlaces;

    return AppInsetTile(
      borderRadius: BorderRadius.circular(context.rs(8)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(context.rs(8)),
          onTap: canPick
              ? () => _openPlacePicker(context, options, selectedPid, vm)
              : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: context.rs(44)),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.rsi(10),
                vertical: context.rsi(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: context.rs(18),
                    color: cs.onSurfaceVariant,
                  ),
                  SizedBox(width: context.rsi(8)),
                  Text(
                    '현장',
                    style: tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(width: context.rsi(10)),
                  Expanded(
                    child: Text(
                      loadingPlaces
                          ? '현장 불러오는 중…'
                          : _selectedPlaceLabel(
                              options, selectedPid, hasPlaces),
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: canPick || loadingPlaces
                            ? cs.onSurface
                            : cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    loadingPlaces
                        ? Icons.hourglass_empty_rounded
                        : Icons.expand_more_rounded,
                    size: context.rs(22),
                    color: canPick || loadingPlaces
                        ? cs.onSurfaceVariant
                        : cs.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _selectedPlaceLabel(
    List<PlaceDropDownModel> options,
    int selectedPid,
    bool hasPlaces,
  ) {
    if (!hasPlaces) return '현장 없음';
    for (final p in options) {
      if (p.pid == selectedPid) return p.pname;
    }
    return options.isNotEmpty ? options.first.pname : '전체 현장';
  }

  Future<void> _openPlacePicker(
    BuildContext context,
    List<PlaceDropDownModel> options,
    int selectedPid,
    WorkerViewModel vm,
  ) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetCtx) {
        final cs = Theme.of(sheetCtx).colorScheme;
        final tt = Theme.of(sheetCtx).textTheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                sheetCtx.rsi(20),
                sheetCtx.rsi(4),
                sheetCtx.rsi(20),
                sheetCtx.rsi(8),
              ),
              child: Text(
                '현장 선택',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (ctx, index) {
                  final p = options[index];
                  final selected = p.pid == selectedPid;
                  return ListTile(
                    title: Text(
                      p.pname,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: selected
                        ? Icon(Icons.check_rounded, color: cs.primary)
                        : null,
                    selected: selected,
                    onTap: () => Navigator.of(sheetCtx).pop(p.pid),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
    if (picked == null || !mounted) return;
    await vm.setWorkCostPlaceFilter(
      picked,
      refetchList: widget.uniqueHumanKey == null,
    );
  }
}

class WorkCostPaymentFooter extends ConsumerWidget {
  const WorkCostPaymentFooter({super.key, this.uniqueHumanKey});

  /// 인력 상세 화면 — 해당 인력 총액·선택만 표시.
  final String? uniqueHumanKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workerProvider);
    final vm = ref.read(workerProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final scopedHuman = uniqueHumanKey;
    final totals = vm.footerTotalsFor(uniqueHumanKey: scopedHuman);
    final selection = vm.footerSelectionFor(uniqueHumanKey: scopedHuman);
    final canPay = vm.footerCanPayFor(uniqueHumanKey: scopedHuman);
    final canUnpay = vm.footerCanUnpayFor(uniqueHumanKey: scopedHuman);
    final hasSelection = selection.hasSelection;
    final selectedUnpaid = vm.footerSelectedUnpaidCostFor(
      uniqueHumanKey: scopedHuman,
    );
    final selectedPaid = vm.footerSelectedPaidCostFor(
      uniqueHumanKey: scopedHuman,
    );

    Widget amountRow(String label, String value, {Color? valueColor}) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.rsi(1)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            Text(
              value,
              style: tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: valueColor ?? cs.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    final actionBtnStyle = FilledButton.styleFrom(
      minimumSize: Size(context.rs(0), context.rs(40)),
      padding: EdgeInsets.symmetric(horizontal: context.rsi(12)),
      visualDensity: VisualDensity.standard,
      textStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
    final outlineBtnStyle = OutlinedButton.styleFrom(
      minimumSize: Size(context.rs(0), context.rs(40)),
      padding: EdgeInsets.symmetric(horizontal: context.rsi(12)),
      visualDensity: VisualDensity.standard,
      textStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );

    return Material(
      elevation: 6,
      color: cs.appCardSurface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.rsi(12),
            context.rsi(10),
            context.rsi(12),
            context.rsi(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        amountRow(
                          scopedHuman == null ? '인건비 총액' : '인건비 합계',
                          getPrice(
                            price: totals.total,
                            isTaxApply: state.isTaxApply,
                          ),
                        ),
                        amountRow(
                          scopedHuman == null ? '미지급 총액' : '미지급 합계',
                          getPrice(
                            price: totals.unpaid,
                            isTaxApply: state.isTaxApply,
                          ),
                          valueColor: cs.error,
                        ),
                        if (hasSelection) ...[
                          amountRow(
                            '선택 미지급',
                            getPrice(
                              price: selectedUnpaid,
                              isTaxApply: state.isTaxApply,
                            ),
                            valueColor: cs.primary,
                          ),
                          if (selectedPaid > 0)
                            amountRow(
                              '선택 지급완료',
                              getPrice(
                                price: selectedPaid,
                                isTaxApply: state.isTaxApply,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (hasSelection) ...[
                SizedBox(height: context.rsi(8)),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: vm.clearWorkCostCheckboxSelection,
                    icon: Icon(
                      Icons.deselect_rounded,
                      size: context.rs(18),
                    ),
                    label: const Text('선택 해제'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.primary,
                      backgroundColor:
                          cs.primaryContainer.withValues(alpha: 0.42),
                      side: BorderSide(
                        color: cs.primary.withValues(alpha: 0.5),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rsi(12),
                        vertical: context.rsi(7),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.standard,
                      textStyle: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(height: context.rsi(10)),
              Row(
                children: [
                  if (canUnpay) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            vm.updateSelectedWorkCostsToIncomplete(context),
                        style: outlineBtnStyle,
                        child: const Text('미지급으로'),
                      ),
                    ),
                    SizedBox(width: context.rsi(10)),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: canPay
                          ? () => vm.updateWorkCostsToComplete(context)
                          : null,
                      style: actionBtnStyle,
                      child: const Text('지급하기'),
                    ),
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
