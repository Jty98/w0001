import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
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
    final maxHeight = (screenH * 0.60).clamp(400.0, 520.0).toDouble();
    final calHeight = (screenH * 0.34).clamp(240.0, 310.0).toDouble();

    return showDialog<DateTime>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          '날짜 선택',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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
    final cs = Theme.of(context).colorScheme;
    final displayedRevenues = [...state.revenueList]
      ..sort((a, b) {
        final da = parseFlexibleDateString(a.rdate);
        final db = parseFlexibleDateString(b.rdate);
        final cmp = _latestFirst ? db.compareTo(da) : da.compareTo(db);
        if (cmp != 0) return cmp;
        return _latestFirst ? b.rid.compareTo(a.rid) : a.rid.compareTo(b.rid);
      });

    final cumulativeByRid = <int, int>{};
    var additionalRunning = 0;
    final forCumulative = [...state.revenueList]
      ..sort((a, b) {
        final da = parseFlexibleDateString(a.rdate);
        final db = parseFlexibleDateString(b.rdate);
        final cmp = da.compareTo(db);
        if (cmp != 0) return cmp;
        return a.rid.compareTo(b.rid);
      });
    for (final r in forCumulative) {
      additionalRunning += r.rprice;
      cumulativeByRid[r.rid] = additionalRunning;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(placeInfo.pname),
      ),
      persistentFooterAlignment: AlignmentDirectional.topCenter,
      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              buildSummaryItem(
                title: '공사 총액',
                price: getPrice(price: placeInfo.pcontractTotal),
                textColor: Colors.black,
              ),
              buildSummaryItem(
                title: '총 수익금',
                price:
                    getPrice(price: placeInfo.pfirstrevenue + vm.totalRevenue),
                textColor: Colors.green,
              ),
              buildSummaryItem(
                title: '잔금',
                price: getPrice(
                  price: (placeInfo.pcontractTotal -
                              (placeInfo.pfirstrevenue + vm.totalRevenue)) <
                          0
                      ? 0
                      : (placeInfo.pcontractTotal -
                          (placeInfo.pfirstrevenue + vm.totalRevenue)),
                ),
                textColor: Colors.deepPurple,
              ),
              buildSummaryItem(
                title:
                    '총 지출금 (${formatDateTimeRangeToString(state.dateTimeRange)})',
                price: getPrice(price: -vm.totalPrice),
                textColor: Colors.red,
                isTwoLine: true,
              ),
              const Divider(),
              buildSummaryItem(
                title: '순이익',
                price: getPrice(
                  price: (placeInfo.pfirstrevenue + vm.totalRevenue) -
                      vm.totalPrice,
                ),
                textColor: Colors.blue,
              ),
              if (placeInfo.pcontractTotal > 0) ...[
                buildSummaryItem(
                  title: '이익률',
                  price:
                      '${(((placeInfo.pfirstrevenue + vm.totalRevenue) - vm.totalPrice) / placeInfo.pcontractTotal * 100).toStringAsFixed(1)}%',
                  textColor: Colors.blueGrey,
                ),
              ],
            ],
          ),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              child: Text(
                '선수금',
                style: normalStyle,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Card(
                child: ListTile(
                  leading: const Text(''),
                  title: const Text('선수금'),
                  trailing: Text(
                    getPrice(price: placeInfo.pfirstrevenue),
                    style: normalStyle,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '추가 수익금',
                      style: normalStyle,
                    ),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('최신순'),
                        icon: Icon(Icons.north_rounded, size: 16),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('오래된순'),
                        icon: Icon(Icons.south_rounded, size: 16),
                      ),
                    ],
                    selected: {_latestFirst},
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onSelectionChanged: (next) {
                      if (next.isEmpty) return;
                      setState(() => _latestFirst = next.first);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: displayedRevenues.length + 1,
                itemBuilder: (context, index) {
                  if (index < displayedRevenues.length) {
                    final revenue = displayedRevenues[index];
                    final additionalCumulative = cumulativeByRid[revenue.rid] ?? revenue.rprice;
                    final totalCumulative = placeInfo.pfirstrevenue + additionalCumulative;
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
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            onPressed: (slidableCtx) => showDialog<void>(
                              context: slidableCtx,
                              builder: (dialogCtx) => deleteDialog(
                                onPressed: () =>
                                    vm.deleteRevenue(rid: revenue.rid).then(
                                          (value) {
                                            if (dialogCtx.mounted) {
                                              Navigator.of(dialogCtx).pop();
                                            }
                                          },
                                        ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          vm.dialogRNameController.text = revenue.rname;
                          vm.dialogRPriceController.text = getPrice(
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
                            builder: (dialogCtx) => Dialog(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color:
                                      const Color.fromARGB(255, 243, 243, 243),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 15),
                                      child: Text('수정', style: bigStyle),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 10,
                                        left: 20,
                                        right: 20,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () async {
                                                final picked =
                                                    await _pickDateWithScrollableCalendar(
                                                  dialogCtx,
                                                  initialDay:
                                                      state.dialogRevenuePickedDay,
                                                );
                                                if (picked != null) {
                                                  vm.setDialogRevenuePickedDay(
                                                    picked,
                                                  );
                                                }
                                              },
                                              icon: const Icon(Icons.event),
                                              label: Text(
                                                formatDateTimeWeekDayToString(
                                                  state.dialogRevenuePickedDay,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 10,
                                        bottom: 3,
                                      ),
                                      child: AddTextField(
                                        tController: vm.dialogRNameController,
                                        labelText: '수익 내용',
                                        isPrice: false,
                                        height: 60,
                                        keyboardType: TextInputType.text,
                                        readOnly: false,
                                        onChanged: (_) {},
                                      ),
                                    ),
                                    AddTextField(
                                      tController: vm.dialogRPriceController,
                                      labelText: '추가금',
                                      isPrice: true,
                                      height: 60,
                                      keyboardType: TextInputType.number,
                                      readOnly: false,
                                      onChanged: (_) {},
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dialogCtx).pop(),
                                          child: const Text(
                                            '취소',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => vm
                                              .updateRevenue(rid: revenue.rid)
                                              .then((value) {
                                            if (dialogCtx.mounted) {
                                              Navigator.of(dialogCtx).pop();
                                            }
                                            if (context.mounted) {
                                              showDialog<void>(
                                                context: context,
                                                builder: (_) => saveDialog(
                                                  text: '수정되었습니다.',
                                                ),
                                              );
                                            }
                                          }),
                                          child: const Text('수정'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 15,
                              backgroundColor: cs.primaryContainer,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                            ),
                            title: Text(revenue.rname),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                    ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _smallInfoChip(
                                      context,
                                      label:
                                          '추가 누적 ${getPrice(price: additionalCumulative)}',
                                    ),
                                    _smallInfoChip(
                                      context,
                                      label:
                                          '총 수익 ${getPrice(price: totalCumulative)}',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Text(
                              getPrice(price: revenue.rprice),
                              style: normalStyle,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 20,
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 6, bottom: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          final picked =
                                              await _pickDateWithScrollableCalendar(
                                            context,
                                            initialDay: state.revenuePickedDay,
                                          );
                                          if (picked != null) {
                                            vm.setRevenuePickedDay(picked);
                                          }
                                        },
                                        icon: const Icon(Icons.event),
                                        label: Text(
                                          formatDateTimeWeekDayToString(
                                            state.revenuePickedDay,
                                          ),
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
                                tController: vm.rNameController,
                                labelText: '내용 (선택)',
                                readOnly: false,
                                isPrice: false,
                                keyboardType: TextInputType.text,
                              ),
                              AddTextField(
                                border: InputBorder.none,
                                height: 50,
                                witdh: MediaQuery.of(context).size.width,
                                tController: vm.rPriceController,
                                labelText: '추가금',
                                readOnly: false,
                                isPrice: true,
                                keyboardType: TextInputType.number,
                                onChanged: (value) =>
                                    vm.updateRevenueController(value),
                              ),
                            ],
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: vm.rPriceController.text.isEmpty
                            ? null
                            : () => vm.insertRevenue(),
                        child: const Text('추가', style: normalStyle),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSummaryItem({
    required String title,
    required String price,
    required Color textColor,
    bool? isTwoLine,
    TextStyle? textStyle,
  }) {
    return SizedBox(
      height: (isTwoLine ?? false) ? 40 : 25,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontSize: 15,
              ),
            ),
          ),
          Text(
            price,
            style: textStyle ??
                TextStyle(
                  fontSize: 15,
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _smallInfoChip(
    BuildContext context, {
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: cs.onSecondaryContainer,
        ),
      ),
    );
  }
}
