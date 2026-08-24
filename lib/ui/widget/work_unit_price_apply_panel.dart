import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/work_unit_preset.dart';
import 'package:w0001/presentation/viewmodel/worker_rank_wage_settings_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/ui/widget/work_unit_chip_selector.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 인건비 금액 필드 위에 두는 공수 선택 — 컨트롤러에 계산 금액을 넣는다.
class WorkUnitPriceApplyPanel extends ConsumerStatefulWidget {
  const WorkUnitPriceApplyPanel({
    super.key,
    required this.priceController,
    required this.currentPrice,
    this.hdailyWage = 0,
    this.workerHid,
    this.onApplied,
  });

  final TextEditingController priceController;
  final int currentPrice;

  /// 현재 금액이 0일 때만 쓰는 역할/인력 일당 폴백.
  final int hdailyWage;
  final int? workerHid;
  final VoidCallback? onApplied;

  @override
  ConsumerState<WorkUnitPriceApplyPanel> createState() =>
      _WorkUnitPriceApplyPanelState();
}

class _WorkUnitPriceApplyPanelState
    extends ConsumerState<WorkUnitPriceApplyPanel> {
  String? _selectedUnitId;
  var _userPickedUnit = false;

  int _lookupHumanWage() {
    final hid = widget.workerHid;
    if (hid == null || hid <= 0) return 0;
    for (final h in ref.read(workerProvider).workerInfoList) {
      if (h.hid == hid) return h.hdailyWage;
    }
    return 0;
  }

  int _baseWage() {
    final fromHuman =
        widget.hdailyWage > 0 ? widget.hdailyWage : _lookupHumanWage();
    return WorkUnitPreset.resolveBaseWage(
      hdailyWage: fromHuman,
      currentAmount: widget.currentPrice,
    );
  }

  bool get _usedRoleFallback =>
      widget.currentPrice <= 0 &&
      (widget.hdailyWage > 0 || _lookupHumanWage() > 0);

  String? _resolveSelectedId({
    required int baseWage,
    required List<WorkUnitPreset> units,
    required String defaultId,
  }) {
    if (_userPickedUnit) return _selectedUnitId;
    return WorkUnitPreset.matchId(
          baseWage: baseWage,
          amount: widget.currentPrice,
          units: units,
        ) ??
        defaultId;
  }

  void _setPriceText(int amount) {
    widget.priceController.text =
        amount > 0 ? getPrice(price: amount, isContainWon: false) : '';
    widget.priceController.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.priceController.text.length),
    );
  }

  void _applyUnit(WorkUnitPreset unit, int baseWage) {
    if (baseWage <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기준 금액이 없어 공수를 적용할 수 없습니다.')),
      );
      return;
    }
    final amount = unit.amountFromBase(baseWage);
    setState(() {
      _userPickedUnit = true;
      _selectedUnitId = unit.id;
      _setPriceText(amount);
    });
    widget.onApplied?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // 현재 금액이 없을 때 역할 일당 폴백이 갱신되도록 watch.
    ref.watch(workerProvider.select((s) => s.workerInfoList.length));
    final settings = ref.watch(workerRankWageSettingsProvider).value;
    final units = settings?.workUnits ?? WorkUnitPreset.defaults;
    final defaultId =
        settings?.defaultWorkUnitId ?? WorkUnitPreset.defaultId;
    final baseWage = _baseWage();
    final selectedId = _resolveSelectedId(
      baseWage: baseWage,
      units: units,
      defaultId: defaultId,
    );
    final usedRoleFallback = _usedRoleFallback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(context.rsi(10)),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
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
                usedRoleFallback
                    ? '기준 일당 (역할)'
                    : '기준 금액 (현재 지정액 = 1공수)',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: context.rsi(2)),
              Text(
                baseWage > 0 ? getPrice(price: baseWage) : '기준 금액 없음',
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        SizedBox(height: context.rsi(10)),
        WorkUnitChipSelector(
          units: units,
          selectedId: selectedId,
          enabled: baseWage > 0,
          dense: true,
          onSelected: (unit) => _applyUnit(unit, baseWage),
        ),
        SizedBox(height: context.rsi(4)),
        Text(
          '공수 선택 시 금액에 반영됩니다. 직접 수정도 가능합니다.',
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
