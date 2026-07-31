import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/revenue_model.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show placeUseCaseProvider;
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/theme/app_segmented_button.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';

class PlaceRevenueScreen extends ConsumerStatefulWidget {
  final PlaceInfoModel placeInfo;
  const PlaceRevenueScreen({super.key, required this.placeInfo});

  @override
  ConsumerState<PlaceRevenueScreen> createState() => _PlaceRevenueScreenState();
}

class _PlaceRevenueScreenState extends ConsumerState<PlaceRevenueScreen> {
  bool _latestFirst = true;
  bool _isSavingRevenue = false;
  late int _initialRevenue;

  /// Provider dispose와 분리(삭제/전역 fetch 직후에도 유효)
  late final TextEditingController _rNameController;
  late final TextEditingController _rPriceController;
  late final TextEditingController _dialogRNameController;
  late final TextEditingController _dialogRPriceController;

  @override
  void initState() {
    super.initState();
    _initialRevenue = widget.placeInfo.pfirstrevenue;
    _rNameController = TextEditingController();
    _rPriceController = TextEditingController();
    _dialogRNameController = TextEditingController();
    _dialogRPriceController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(placeDetailProvider(widget.placeInfo.pid!));
      if (_rNameController.text.isEmpty) {
        _rNameController.text = nextJangeumLabelForRevenueList(s.revenueList);
      }
    });
  }

  @override
  void dispose() {
    _rNameController.dispose();
    _rPriceController.dispose();
    _dialogRNameController.dispose();
    _dialogRPriceController.dispose();
    super.dispose();
  }

  bool _canAddRevenue(PlaceDetailState state) {
    final raw = _rPriceController.text.trim().replaceAll(RegExp(r'[,원]'), '');
    if (raw.isEmpty) return false;
    if (state.revenuePickedDay == null) return false;
    return true;
  }

  Future<DateTime?> _pickDateWithScrollableCalendar(
    BuildContext context, {
    required DateTime initialDay,
  }) async {
    DateTime? pickedDay = DateTime(
      initialDay.year,
      initialDay.month,
      initialDay.day,
    );

    final screenH = MediaQuery.sizeOf(context).height;
    final maxHeight =
        (screenH * 0.60).clamp(context.rs(400), context.rs(520)).toDouble();
    final calHeight =
        (screenH * 0.34).clamp(context.rs(240), context.rs(310)).toDouble();

    return showDialog<DateTime>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Padding(
                  padding: EdgeInsets.only(bottom: dialogCtx.rsi(8)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: dialogCtx.rsi(10)),
                        child: Text(
                          '날짜 선택',
                          style: Theme.of(dialogCtx)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      ScrollableCalendarWidget(
                        height: calHeight,
                        initialSelectedDay: pickedDay,
                        useSingleDaySelection: true,
                        showViewModeToggle: false,
                        disableDateSelectionHighlight: true,
                        onDayPicked: (d) {
                          setDialogState(() => pickedDay = d);
                        },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: const Text(
                              '취소',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogCtx).pop(pickedDay),
                            child: const Text('확인'),
                          ),
                          const SizedBox(width: 8),
                        ],
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

  @override
  Widget build(BuildContext context) {
    final placeInfo = widget.placeInfo;
    final state = ref.watch(placeDetailProvider(placeInfo.pid!));
    final vm = ref.read(placeDetailProvider(placeInfo.pid!).notifier);
    ref.listen(placeDetailProvider(placeInfo.pid!), (prev, next) {
      if (!mounted) return;
      if (_rNameController.text.trim().isNotEmpty) return;
      _rNameController.text = nextJangeumLabelForRevenueList(next.revenueList);
    });
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final displayedRevenues = [...state.revenueList]..sort((a, b) {
        final da = parseFlexibleDateString(a.rdate);
        final db = parseFlexibleDateString(b.rdate);
        final cmp = _latestFirst ? db.compareTo(da) : da.compareTo(db);
        if (cmp != 0) return cmp;
        return _latestFirst ? b.rid.compareTo(a.rid) : a.rid.compareTo(b.rid);
      });
    final totalRevenue = _initialRevenue + vm.totalRevenue;
    final remaining = placeInfo.pcontractTotal - totalRevenue;
    final balance = remaining < 0 ? 0 : remaining;
    final profit = totalRevenue - vm.totalPrice;

    Future<void> _openInitialRevenueEditDialog() async {
      final controller = TextEditingController(
        text: getPrice(price: _initialRevenue, isContainWon: false),
      );
      var isSaving = false;
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  ctx.rsi(16),
                  ctx.rsi(14),
                  ctx.rsi(16),
                  ctx.rsi(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '선수금 수정',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: ctx.rsi(4)),
                    Text(
                      '초기 수금액을 수정하면 잔금/순이익 계산에 즉시 반영됩니다.',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: ctx.rsi(10)),
                    AddTextField(
                      tController: controller,
                      labelText: '선수금',
                      isPrice: true,
                      height: ctx.rs(60),
                      keyboardType: TextInputType.number,
                      readOnly: isSaving,
                      onChanged: (_) {},
                    ),
                    SizedBox(height: ctx.rsi(8)),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(ctx).pop(),
                            child: const Text('취소'),
                          ),
                        ),
                        SizedBox(width: ctx.rsi(8)),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final raw = controller.text
                                        .trim()
                                        .replaceAll(RegExp(r'[,원]'), '');
                                    final nextRevenue = int.tryParse(raw);
                                    if (nextRevenue == null || nextRevenue < 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('선수금 금액을 확인해주세요.'),
                                        ),
                                      );
                                      return;
                                    }
                                    setDialogState(() => isSaving = true);
                                    try {
                                      final pid = placeInfo.pid;
                                      if (pid == null) return;
                                      final model = PlaceModel(
                                        pid: pid,
                                        pname: placeInfo.pname,
                                        pcomplete: placeInfo.pcomplete,
                                        pstart: placeInfo.pstart,
                                        pend: placeInfo.pend,
                                        paddress: placeInfo.paddress,
                                        prevenue: nextRevenue,
                                        pcontractTotal: placeInfo.pcontractTotal,
                                        pcontractDate: '',
                                      );
                                      await ref
                                          .read(placeUseCaseProvider)
                                          .updatePlace(model);
                                      if (!mounted) return;
                                      setState(() => _initialRevenue = nextRevenue);
                                      await FetchData.onDataChanged(
                                        DataChangeEvent.placeSaved
                                            .withPid(placeInfo.pid!),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('선수금이 수정되었습니다.'),
                                        ),
                                      );
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => isSaving = false);
                                      }
                                    }
                                  },
                            icon: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: HammerLoadingIndicator(size: 16),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(isSaving ? '저장 중...' : '저장'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      controller.dispose();
    }

    Future<void> _handleAddRevenue() async {
      setState(() => _isSavingRevenue = true);
      try {
        final err = await vm.insertRevenue(
          rnameOrEmpty: _rNameController.text,
          rpriceRaw: _rPriceController.text,
        );
        if (!mounted) return;
        if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err)),
          );
          return;
        }
        final list =
            ref.read(placeDetailProvider(placeInfo.pid!)).revenueList;
        _rNameController.text = nextJangeumLabelForRevenueList(list);
        _rPriceController.clear();
        await FetchData.onDataChanged(
          DataChangeEvent.revenueSaved.withPid(placeInfo.pid!),
        );
      } finally {
        if (mounted) {
          setState(() => _isSavingRevenue = false);
        }
      }
    }

    Widget buildRevenueRow(RevenueModel revenue, int index) {
      final dateText = revenue.rdate.isEmpty
          ? '-'
          : formatDateTimeWeekDayToString(
              parseFlexibleDateString(revenue.rdate),
            );
      return Slidable(
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              autoClose: true,
              borderRadius: BorderRadius.circular(10),
              label: '삭제',
              icon: Icons.delete,
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
              onPressed: (slidableCtx) => showDialog<void>(
                context: slidableCtx,
                builder: (dialogCtx) => deleteDialog(
                  onPressed: () {
                    vm.deleteRevenue(rid: revenue.rid).then((_) async {
                      await FetchData.onDataChanged(
                        DataChangeEvent.revenueSaved.withPid(placeInfo.pid!),
                      );
                      if (dialogCtx.mounted) {
                        Navigator.of(dialogCtx).pop();
                      }
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            _dialogRNameController.text = revenue.rname;
            _dialogRPriceController.text = getPrice(
              price: revenue.rprice,
              isContainWon: false,
            );
            vm.setDialogRevenuePickedDay(
              revenue.rdate.isEmpty
                  ? DateTime.now()
                  : parseFlexibleDateString(revenue.rdate),
            );
            showDialog<void>(
              context: context,
              builder: (dialogCtx) {
                bool isUpdating = false;
                return StatefulBuilder(
                  builder: (ctx, setDialogState) => Dialog(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: cs.surface,
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          ctx.rsi(16),
                          ctx.rsi(14),
                          ctx.rsi(16),
                          ctx.rsi(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '수익 수정',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: ctx.rsi(4)),
                            Text(
                              '날짜, 내용, 금액을 수정한 뒤 저장하세요.',
                              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                            ),
                            SizedBox(height: ctx.rsi(10)),
                            OutlinedButton.icon(
                              onPressed: isUpdating
                                  ? null
                                  : () async {
                                      final picked =
                                          await _pickDateWithScrollableCalendar(
                                        ctx,
                                        initialDay: state.dialogRevenuePickedDay,
                                      );
                                      if (picked != null) {
                                        vm.setDialogRevenuePickedDay(picked);
                                      }
                                    },
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: ctx.rsi(10),
                                  horizontal: ctx.rsi(8),
                                ),
                              ),
                              icon: const Icon(Icons.event),
                              label: Text(
                                formatDateTimeWeekDayToString(
                                  state.dialogRevenuePickedDay,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: ctx.rsi(8)),
                            AddTextField(
                              tController: _dialogRNameController,
                              labelText: '수익 내용',
                              isPrice: false,
                              height: ctx.rs(60),
                              keyboardType: TextInputType.text,
                              readOnly: isUpdating,
                              onChanged: (_) {},
                            ),
                            AddTextField(
                              tController: _dialogRPriceController,
                              labelText: '추가금',
                              isPrice: true,
                              height: ctx.rs(60),
                              keyboardType: TextInputType.number,
                              readOnly: isUpdating,
                              onChanged: (_) {},
                            ),
                            SizedBox(height: ctx.rsi(8)),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isUpdating
                                        ? null
                                        : () => Navigator.of(ctx).pop(),
                                    child: const Text('취소'),
                                  ),
                                ),
                                SizedBox(width: ctx.rsi(8)),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: isUpdating
                                        ? null
                                        : () async {
                                            setDialogState(
                                                () => isUpdating = true);
                                            try {
                                              final rp = int.tryParse(
                                                    _dialogRPriceController.text
                                                        .trim()
                                                        .replaceAll(
                                                          RegExp(r'[,원]'),
                                                          '',
                                                        ),
                                                  ) ??
                                                  0;
                                              await vm.updateRevenue(
                                                rid: revenue.rid,
                                                rname: _dialogRNameController.text,
                                                rprice: rp,
                                                revenueDate:
                                                    state.dialogRevenuePickedDay,
                                              );
                                              await FetchData.onDataChanged(
                                                DataChangeEvent.revenueSaved
                                                    .withPid(placeInfo.pid!),
                                              );
                                              if (ctx.mounted) {
                                                Navigator.of(ctx).pop();
                                              }
                                              if (context.mounted) {
                                                showDialog<void>(
                                                  context: context,
                                                  builder: (_) => saveDialog(
                                                    text: '수정되었습니다.',
                                                  ),
                                                );
                                              }
                                            } finally {
                                              if (ctx.mounted) {
                                                setDialogState(
                                                    () => isUpdating = false);
                                              }
                                            }
                                          },
                                    icon: isUpdating
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child:
                                                HammerLoadingIndicator(size: 16),
                                          )
                                        : const Icon(Icons.check_rounded),
                                    label: Text(isUpdating ? '저장 중...' : '수정 저장'),
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
              },
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: context.rs(15),
                backgroundColor: cs.primaryContainer,
                child: Text(
                  '${index + 1}',
                  style: tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              title: Text(
                revenue.rname,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                dateText,
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              trailing: Text(
                getPrice(price: revenue.rprice),
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(placeInfo.pname),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              context.rsi(10),
              context.rsi(10),
              context.rsi(10),
              MediaQuery.paddingOf(context).bottom + context.rsi(24),
            ),
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  context.rsi(12),
                  context.rsi(8),
                  context.rsi(12),
                  context.rsi(6),
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    buildSummaryItem(
                      context,
                      title: '공사 총액',
                      price: getPrice(price: placeInfo.pcontractTotal),
                      textColor: cs.onSurface,
                    ),
                    buildSummaryItem(
                      context,
                      title: '총 수익금',
                      price: getPrice(price: totalRevenue),
                      textColor: cs.onSurface,
                    ),
                    buildSummaryItem(
                      context,
                      title: '잔금',
                      price: getPrice(price: balance),
                      textColor: cs.onSurface,
                    ),
                    buildSummaryItem(
                      context,
                      title:
                          '총 지출금 (${formatDateTimeRangeToString(state.dateTimeRange, periodType: state.selectedDayType)})',
                      price: getPrice(price: -vm.totalPrice),
                      textColor: cs.error,
                      isTwoLine: true,
                    ),
                    Divider(color: cs.outlineVariant.withValues(alpha: 0.55)),
                    buildSummaryItem(
                      context,
                      title: '순이익',
                      price: getPrice(price: profit),
                      textColor: cs.onSurface,
                      textStyle: tt.titleSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (placeInfo.pcontractTotal > 0) ...[
                      buildSummaryItem(
                        context,
                        title: '이익률',
                        price:
                            '${(profit / placeInfo.pcontractTotal * 100).toStringAsFixed(1)}%',
                        textColor: cs.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: context.rsi(12)),
              Container(
                padding: EdgeInsets.fromLTRB(
                  context.rsi(10),
                  context.rsi(10),
                  context.rsi(10),
                  context.rsi(8),
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: context.rsi(18),
                            color: cs.onSurface,
                          ),
                          SizedBox(width: context.rsi(6)),
                          Text(
                            '수금 내역',
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('최신순'),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('오래된순'),
                        ),
                      ],
                      selected: {_latestFirst},
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        shape: AppSegmentedButton.segmentShape,
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: cs.surface,
                        foregroundColor: cs.onSurfaceVariant,
                        selectedBackgroundColor: cs.primary,
                        selectedForegroundColor: cs.onPrimary,
                        side: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.7),
                        ),
                      ),
                      onSelectionChanged: (next) {
                        if (next.isEmpty) return;
                        setState(() => _latestFirst = next.first);
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.rsi(8)),
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: context.rs(15),
                    backgroundColor: cs.primaryContainer,
                    child: Icon(
                      Icons.savings_outlined,
                      size: context.rs(16),
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    '선수금',
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '초기 수금',
                    style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  trailing: Text(
                    getPrice(price: _initialRevenue),
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  onTap: _openInitialRevenueEditDialog,
                ),
              ),
              if (displayedRevenues.isNotEmpty)
                ...List.generate(displayedRevenues.length, (i) {
                  return Padding(
                    padding: EdgeInsets.only(top: context.rsi(6)),
                    child: buildRevenueRow(displayedRevenues[i], i),
                  );
                })
              else
                Padding(
                  padding: EdgeInsets.symmetric(vertical: context.rsi(16)),
                  child: Text(
                    '추가 수금 내역이 없습니다.',
                    textAlign: TextAlign.center,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              SizedBox(height: context.rsi(12)),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: context.rsi(12),
                    horizontal: context.rsi(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '수익 추가 입력',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: context.rsi(4)),
                      Text(
                        '날짜와 금액을 입력한 뒤 저장하세요.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          top: context.rsi(6),
                          bottom: context.rsi(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final current = state.revenuePickedDay;
                                  final picked =
                                      await _pickDateWithScrollableCalendar(
                                    context,
                                    initialDay: current ?? DateTime.now(),
                                  );
                                  if (picked != null) {
                                    vm.setRevenuePickedDay(picked);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: context.rsi(12),
                                    horizontal: context.rsi(8),
                                  ),
                                ),
                                icon: Icon(Icons.event, size: context.rs(20)),
                                label: Text(
                                  state.revenuePickedDay == null
                                      ? '날짜 선택'
                                      : formatDateTimeWeekDayToString(
                                          state.revenuePickedDay!,
                                        ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AddTextField(
                        border: const UnderlineInputBorder(),
                        height: 63,
                        witdh: MediaQuery.of(context).size.width,
                        tController: _rNameController,
                        labelText: '수익 내용',
                        readOnly: false,
                        isPrice: false,
                        keyboardType: TextInputType.text,
                        onChanged: (_) => setState(() {}),
                      ),
                      SizedBox(height: context.rsi(4)),
                      AddTextField(
                        border: InputBorder.none,
                        height: 50,
                        witdh: MediaQuery.of(context).size.width,
                        tController: _rPriceController,
                        labelText: '추가금',
                        readOnly: false,
                        isPrice: true,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                      SizedBox(height: context.rsi(8)),
                      FilledButton.icon(
                        onPressed: (_canAddRevenue(state) && !_isSavingRevenue)
                            ? _handleAddRevenue
                            : null,
                        icon: _isSavingRevenue
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: HammerLoadingIndicator(size: 18),
                              )
                            : const Icon(Icons.add_rounded),
                        label: Text(_isSavingRevenue ? '저장 중...' : '추가 저장'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isSavingRevenue)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.12),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rsi(16),
                      vertical: context.rsi(12),
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HammerLoadingIndicator(size: 34),
                        SizedBox(height: 8),
                        Text('수익 저장 중입니다...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildSummaryItem(
    BuildContext context, {
    required String title,
    required String price,
    required Color textColor,
    bool? isTwoLine,
    TextStyle? textStyle,
  }) {
    final tt = Theme.of(context).textTheme;
    return SizedBox(
      height: context.rs((isTwoLine ?? false) ? 44 : 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.start,
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            price,
            style: textStyle ??
                tt.titleSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }

}
