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

class PlaceRevenueScreen extends ConsumerWidget {
  final PlaceInfoModel placeInfo;
  const PlaceRevenueScreen({super.key, required this.placeInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(placeDetailProvider(placeInfo.pid!));
    final vm = ref.read(placeDetailProvider(placeInfo.pid!).notifier);
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
                title: '총 수익금',
                price:
                    getPrice(price: placeInfo.pfirstrevenue + vm.totalRevenue),
                textColor: Colors.green,
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              child: Text(
                '추가 수익금',
                style: normalStyle,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: state.revenueList.length + 1,
                itemBuilder: (context, index) {
                  if (index < state.revenueList.length) {
                    final revenue = state.revenueList[index];
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
                            leading: Text('${index + 1}차'),
                            title: Text(revenue.rname),
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
}
