import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:kpostal/kpostal.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';

/// DB 문자열 → 캘린더 초기 구간 (파싱 실패 시 null).
(DateTime?, DateTime?) _parsedPlaceRange(PlaceInfoModel element) {
  try {
    if (element.pstart.isEmpty) return (null, null);
    final s = DateTime.parse(element.pstart);
    final dStart = DateTime(s.year, s.month, s.day);
    if (element.pend == '0' || element.pend.isEmpty) {
      return (dStart, dStart);
    }
    final p = DateTime.parse(element.pend);
    final dEnd = DateTime(p.year, p.month, p.day);
    return (dStart, dEnd);
  } catch (_) {
    return (null, null);
  }
}

class PlaceScreen extends ConsumerWidget {
  const PlaceScreen({super.key});

  static const String _addressSeparator = '||';

  (String, String) _splitAddress(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return ('', '');
    if (t.contains(_addressSeparator)) {
      final parts = t.split(_addressSeparator);
      final main = parts.isNotEmpty ? parts.first.trim() : '';
      final detail = parts.length > 1 ? parts.sublist(1).join(_addressSeparator).trim() : '';
      return (main, detail);
    }
    return (t, '');
  }

  String _joinAddress(String main, String detail) {
    final m = main.trim();
    final d = detail.trim();
    if (m.isEmpty && d.isEmpty) return '';
    if (d.isEmpty) return m;
    if (m.isEmpty) return d;
    return '$m$_addressSeparator$d';
  }

  Future<void> _openAddressSearch(
    BuildContext context,
    TextEditingController addressController,
  ) async {
    Kpostal? result;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => KpostalView(
          callback: (Kpostal value) {
            result = value;
          },
        ),
      ),
    );
    final selected = result;
    if (selected == null) return;
    final road = selected.address.trim();
    final jibun = selected.jibunAddress.trim();
    final picked = road.isNotEmpty ? road : jibun;
    if (picked.isNotEmpty) {
      addressController.text = picked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(placeListProvider);
    final viewModel = ref.read(placeListProvider.notifier);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('현장 관리'),
          actions: [
            _buildAppBarIconButton(context, ref, viewModel),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildSegmentButton(state, viewModel),
              Expanded(
                child: _buildListView(context, ref, state, viewModel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    WidgetRef ref,
    PlaceListState state,
    PlaceListViewModel viewModel,
  ) {
    if (state.filteredPlaceList.isEmpty) {
      final label = state.placeState == PlaceState.incomplete ? '진행중인' : '완료된';
      return Center(
        child: Text(
          '$label 현장이 없습니다.',
          style: normalStyle,
        ),
      );
    }

    return ListView.builder(
      itemCount: state.filteredPlaceList.length,
      itemBuilder: (ctx, index) => _buildPlaceListTile(
        context: ctx,
        ref: ref,
        element: state.filteredPlaceList[index],
        index: index,
        viewModel: viewModel,
      ),
    );
  }

  Padding _buildSegmentButton(
    PlaceListState state,
    PlaceListViewModel viewModel,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: CupertinoSlidingSegmentedControl<PlaceState>(
        groupValue: state.placeState,
        children: const {
          PlaceState.incomplete: Text('진행중'),
          PlaceState.complete: Text('완료'),
        },
        onValueChanged: viewModel.stateValueChanged,
      ),
    );
  }

  Widget _buildAppBarIconButton(
    BuildContext context,
    WidgetRef ref,
    PlaceListViewModel viewModel,
  ) {
    return IconButton(
      tooltip: '현장 추가',
      onPressed: () async {
        viewModel.setPlaceDialogDateRange(null, null);
        await showDialog<void>(
          context: context,
          builder: (dialogCtx) => _placeDialog(
            isAdd: true,
            initialCalendarStart: null,
            initialCalendarEnd: null,
            onConfirm: (_, __) async {
              await viewModel.insertPlace();
              final cur = ref.read(placeListProvider);
              if (cur.updateText.isEmpty) {
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                viewModel.resetTextController();
              }
            },
            nameController: viewModel.placeNameController,
            revenueController: viewModel.placeRevenueController,
            contractTotalController: viewModel.placeContractTotalController,
            addressController: viewModel.placeAddressController,
            onPlaceDateRangeChanged: viewModel.setPlaceDialogDateRange,
          ),
        );
        viewModel.resetTextController();
      },
      icon: const Icon(Icons.add),
    );
  }

  Dialog _placeDialog({
    required bool isAdd,
    required TextEditingController nameController,
    required TextEditingController revenueController,
    required TextEditingController contractTotalController,
    required TextEditingController addressController,
    required Future<void> Function(DateTime? rangeStart, DateTime? rangeEnd)
        onConfirm,
    DateTime? initialCalendarStart,
    DateTime? initialCalendarEnd,
    void Function(DateTime? start, DateTime? end)? onPlaceDateRangeChanged,
  }) {
    return Dialog(
      child: Builder(
        builder: (context) {
          final screenH = MediaQuery.sizeOf(context).height;
          final maxHeight = (screenH * 0.82).clamp(560.0, 760.0).toDouble();
          final calendarHeight = (screenH * 0.34).clamp(250.0, 320.0).toDouble();
          DateTime? rangeStart = initialCalendarStart;
          DateTime? rangeEnd = initialCalendarEnd ?? initialCalendarStart;
          final (initialMainAddress, initialDetailAddress) =
              _splitAddress(addressController.text);
          final mainAddressController =
              TextEditingController(text: initialMainAddress);
          final detailAddressController =
              TextEditingController(text: initialDetailAddress);
          var showAddressSection = initialMainAddress.isNotEmpty || initialDetailAddress.isNotEmpty;

          return Consumer(
            builder: (context, consumerRef, _) {
              final vmState = consumerRef.watch(placeListProvider);
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  final cs = Theme.of(context).colorScheme;
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                isAdd ? '현장 추가' : '현장 수정',
                                style: bigStyle,
                              ),
                            ),
                            const SizedBox(height: 12),
                            AddTextField(
                              tController: nameController,
                              labelText: '현장 이름 (필수)',
                              isPrice: false,
                              readOnly: false,
                              witdh: double.infinity,
                            ),
                            AddTextField(
                              tController: contractTotalController,
                              labelText: '공사금액',
                              isPrice: true,
                              keyboardType: TextInputType.number,
                              readOnly: false,
                              witdh: double.infinity,
                            ),
                            AddTextField(
                              tController: revenueController,
                              labelText: '선수금',
                              isPrice: true,
                              keyboardType: TextInputType.number,
                              readOnly: false,
                              witdh: double.infinity,
                            ),
                            const SizedBox(height: 2),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () =>
                                  setDialogState(() => showAddressSection = !showAddressSection),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 18, color: cs.primary),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        '현장 주소 (선택입력)',
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Icon(
                                      showAddressSection
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (showAddressSection) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _openAddressSearch(
                                  context,
                                  mainAddressController,
                                ),
                                child: AbsorbPointer(
                                  child: AddTextField(
                                    tController: mainAddressController,
                                    labelText: '현장 주소 (선택입력)',
                                    isPrice: false,
                                    keyboardType: TextInputType.text,
                                    readOnly: true,
                                    witdh: double.infinity,
                                  ),
                                ),
                              ),
                              AddTextField(
                                tController: detailAddressController,
                                labelText: '상세주소 (직접입력)',
                                isPrice: false,
                                keyboardType: TextInputType.text,
                                readOnly: false,
                                witdh: double.infinity,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: cs.surfaceContainerLowest,
                                border: Border.all(
                                  color: cs.outlineVariant.withValues(alpha: 0.6),
                                ),
                              ),
                              child: ScrollableCalendarWidget(
                                height: calendarHeight,
                                initialRangeStart: initialCalendarStart,
                                initialRangeEnd:
                                    initialCalendarEnd ?? initialCalendarStart,
                                showViewModeToggle: false,
                                showRangeSummarySection: false,
                                disableDateSelectionHighlight: true,
                                onRangeChanged: (s, e) {
                                  rangeStart = s;
                                  rangeEnd = e;
                                  onPlaceDateRangeChanged?.call(s, e);
                                  setDialogState(() {});
                                },
                              ),
                            ),
                            if (vmState.updateText.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  vmState.updateText,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 44),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      '취소',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () async {
                                      addressController.text = _joinAddress(
                                        mainAddressController.text,
                                        detailAddressController.text,
                                      );
                                      await onConfirm(rangeStart, rangeEnd);
                                    },
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 44),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text('저장'),
                                  ),
                                ),
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
        },
      ),
    );
  }

  Widget _buildPlaceListTile({
    required BuildContext context,
    required WidgetRef ref,
    required PlaceInfoModel element,
    required int index,
    required PlaceListViewModel viewModel,
  }) {
    final cs = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
    final isComplete = element.pcomplete == 1;
    final accent = isComplete ? Colors.green[700] : cs.primary;

    return Slidable(
      closeOnScroll: true,
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            borderRadius: BorderRadius.circular(10),
            backgroundColor: Colors.green,
            icon: element.pcomplete == 1
                ? Icons.autorenew_outlined
                : Icons.check_circle,
            label: element.pcomplete == 1 ? '진행중으로 변경' : '완료',
            onPressed: (context) {
              viewModel.updatePcomplete(index).then((value) {
                FetchData.fetchAllData();
                ref.read(addCostProvider.notifier).clearSelectedPlace();
              });
            },
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            borderRadius: BorderRadius.circular(10),
            label: '수정',
            icon: Icons.edit,
            backgroundColor: Colors.blue,
            onPressed: (context) {
              TextEditingController nameController =
                  TextEditingController(text: element.pname);
              TextEditingController revenueController = TextEditingController(
                  text: getPrice(
                      price: element.pfirstrevenue, isContainWon: false));
              TextEditingController contractTotalController =
                  TextEditingController(
                      text: getPrice(
                          price: element.pcontractTotal, isContainWon: false));
              final (initStart, initEnd) = _parsedPlaceRange(element);
              TextEditingController addressController =
                  TextEditingController(text: element.paddress);
              showDialog<void>(
                context: context,
                builder: (dialogCtx) => _placeDialog(
                  isAdd: false,
                  nameController: nameController,
                  revenueController: revenueController,
                  contractTotalController: contractTotalController,
                  addressController: addressController,
                  initialCalendarStart: initStart,
                  initialCalendarEnd: initEnd,
                  onPlaceDateRangeChanged: null,
                  onConfirm: (rangeStart, rangeEnd) async {
                    final prevenue = int.tryParse(
                          revenueController.text
                              .trim()
                              .replaceAll(RegExp(r'[,원]'), ''),
                        ) ??
                        -1;
                    final pcontractTotal = int.tryParse(
                          contractTotalController.text
                              .trim()
                              .replaceAll(RegExp(r'[,원]'), ''),
                        ) ??
                        -1;
                    final ok = await viewModel.updatePlace(
                      element.pid!,
                      nameController.text,
                      addressController.text,
                      prevenue,
                      pcontractTotal,
                      rangeStart,
                      rangeEnd,
                    );
                    if (ok && dialogCtx.mounted) {
                      Navigator.of(dialogCtx).pop();
                      await FetchData.fetchAllData();
                      ref.read(addCostProvider.notifier).clearSelectedPlace();
                    }
                  },
                ),
              ).then((value) => viewModel.clearUpdateText());
            },
          ),
          SlidableAction(
            borderRadius: BorderRadius.circular(10),
            backgroundColor: Colors.red,
            icon: Icons.delete,
            label: '삭제',
            onPressed: (slidableCtx) => showDialog<void>(
              context: slidableCtx,
              builder: (dialogCtx) => deleteDialog(
                onPressed: () =>
                    viewModel.deletePlace(element.pid!).then((value) {
                  FetchData.fetchAllData();
                  ref.read(addCostProvider.notifier).clearSelectedPlace();
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                }),
              ),
            ),
          ),
        ],
      ),
      child: InkWell(
        // nested route: /place/detail (분기 화면)
        onTap: () => context.push('/place/detail', extra: element),
        onLongPress: () => showDialog<void>(
          context: context,
          builder: (_) => pageViewDialog(
            title: element.pname,
            height: 500,
            text: formatDuration(element.pstart, element.pend),
            textStyle: const TextStyle(fontSize: 15),
            children: [
              _buildMainTable(element),
              _buildMaterialTable(element),
            ],
          ),
        ),
        child: Card(
          elevation: 0,
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    element.pname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
                const SizedBox(width: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: (accent ?? cs.primary).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      isComplete ? '완료' : '진행중',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: accent ?? cs.primary,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    formatDuration(element.pstart, element.pend),
                    style: subtitleStyle,
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final totalRevenue = element.pfirstrevenue +
                          element.totalAdditionalRevenue;
                      final balance =
                          (element.pcontractTotal - totalRevenue) < 0
                              ? 0
                              : (element.pcontractTotal - totalRevenue);

                      return Row(
                        children: [
                          Expanded(
                            child: _PlaceMetric(
                              label: '공사금액',
                              value: getPrice(price: element.pcontractTotal),
                              icon: Icons.request_quote_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PlaceMetric(
                              label: '수금액',
                              value: getPrice(price: totalRevenue),
                              icon: Icons.trending_up_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PlaceMetric(
                              label: '잔금',
                              value: getPrice(price: balance),
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainTable(PlaceInfoModel element) {
    final totalRevenue = element.pfirstrevenue + element.totalAdditionalRevenue;
    final totalCost = element.mTotal + element.wTotal;
    final balance = (element.pcontractTotal - totalRevenue) < 0
        ? 0
        : (element.pcontractTotal - totalRevenue);
    final profit = totalRevenue - totalCost;
    final margin = element.pcontractTotal <= 0
        ? null
        : (profit / element.pcontractTotal) * 100.0;

    List<TableRowModel> mainRows = [
      TableRowModel(label: ' 총 품수', value: '${element.workerCount}품'),
      TableRowModel(
          label: ' 공사 총액', value: getPrice(price: element.pcontractTotal)),
      TableRowModel(
          label: ' 총 수익',
          value: getPrice(
              price: element.pfirstrevenue + element.totalAdditionalRevenue)),
      TableRowModel(label: ' 잔금', value: getPrice(price: balance)),
      TableRowModel(
          label: ' 총 지출금액',
          value: getPrice(price: element.mTotal + element.wTotal)),
      TableRowModel(label: ' 순 이익', value: getPrice(price: profit)),
      TableRowModel(
        label: ' 이익률',
        value: margin == null ? '-' : '${margin.toStringAsFixed(1)}%',
      ),
      TableRowModel(label: '', value: ''),
      TableRowModel(label: ' 총 인건비', value: getPrice(price: element.wTotal)),
      TableRowModel(label: ' 총 자재비', value: getPrice(price: element.mTotal)),
      TableRowModel(
          label: ' 미지급 인건비', value: getPrice(price: element.wIncomplete)),
    ];

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              '현장 요약',
              style: TextStyle(fontSize: 15),
            ),
          ),
        ),
        Table(
          border: TableBorder.all(color: Colors.grey),
          columnWidths: const {
            0: FixedColumnWidth(100.0),
            1: FixedColumnWidth(170.0),
          },
          children: mainRows.map(
            (row) {
              return TableRow(
                children: [
                  TableCell(
                    child: Text(
                      row.label,
                      style: TextStyle(
                          color: row.label.contains('미지급')
                              ? const Color.fromARGB(255, 236, 28, 13)
                              : Colors.black,
                          fontWeight: row.label.contains('합계')
                              ? FontWeight.bold
                              : null),
                    ),
                  ),
                  TableCell(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${row.value}  ',
                        textAlign: row.align,
                        style: TextStyle(
                            color: row.label.contains('미지급')
                                ? const Color.fromARGB(255, 236, 28, 13)
                                : Colors.black,
                            fontWeight: row.label.contains('합계')
                                ? FontWeight.bold
                                : null),
                      ),
                    ),
                  ),
                ],
              );
            },
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildMaterialTable(PlaceInfoModel element) {
    List<TableRowModel> materialRows = categoryList.map((category) {
      final valueGetter = categoryMapping[category];
      if (valueGetter != null) {
        final value = valueGetter(element);
        return TableRowModel(
          label: ' $category',
          value: getPrice(price: value),
        );
      } else {
        return TableRowModel(label: ' $category', value: '');
      }
    }).toList();

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              '자재비 상세',
              style: TextStyle(fontSize: 15),
            ),
          ),
        ),
        Table(
          border: TableBorder.all(color: Colors.grey),
          columnWidths: const {
            0: FixedColumnWidth(100.0),
            1: FixedColumnWidth(170.0),
          },
          children: materialRows.map((row) {
            return TableRow(
              children: [
                TableCell(child: Text(' ${row.label}')),
                TableCell(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('${row.value}  ', textAlign: row.align),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class TableRowModel {
  final String label;
  final String value;
  final TextAlign align;

  TableRowModel({
    required this.label,
    required this.value,
    this.align = TextAlign.center,
  });
}

class _PlaceMetric extends StatelessWidget {
  const _PlaceMetric({
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.50)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurfaceVariant,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 금액이 커져도 ... 되지 않게, 영역 안에서 자동 축소로 항상 전체를 보여준다.
            SizedBox(
              height: 16,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// end
