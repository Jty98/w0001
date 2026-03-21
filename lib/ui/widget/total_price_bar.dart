import 'package:flutter/material.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';

typedef CategoryTapCallback = void Function(String category);
const placeCategory = ['인건비', '미지급', '자재비', '전체', ...categoryList];

class TotalPriceBar extends StatelessWidget {
  const TotalPriceBar({
    super.key,
    required this.totalCostList,
    required this.categoryTapCallbacks,
  });

  final List<TotalCostModel> totalCostList;
  final Map<String, CategoryTapCallback> categoryTapCallbacks;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey.withValues(alpha: 0.15),
      child: Column(
        children: [
          const Divider(height: 3, thickness: 2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _buildCategoryRows(context),
            ),
          ),
          const Divider(height: 0, thickness: 2),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryRows(BuildContext context) {
    // 위젯 담을 List
    List<Widget> categoryRows = [];

    final materialTapCallback = categoryTapCallbacks['자재비'];
    final workTapCallback = categoryTapCallbacks['인건비'];
    final notPayTapCallback = categoryTapCallbacks['미지급'];
    final totalTapCallback = categoryTapCallbacks['전체'];

    int workCost = 0;
    int materialCost = 0;
    int notPayCost = 0;

    for (var totalCost in totalCostList) {
      if (totalCost.category == 'w') {
        workCost += totalCost.price;
      } else {
        materialCost += totalCost.price;
      }

      if (totalCost.wcomplete == 0) {
        notPayCost += totalCost.price;
      }
    }

    categoryRows.add(
      InkWell(
        onTap: totalTapCallback != null ? () => totalTapCallback('전체') : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 70),
          padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
          child: Column(
            children: [
              const Text('전체', style: mediumStyle),
              Text(getPrice(price: workCost + materialCost),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );

    categoryRows.add(
      InkWell(
        onTap: workTapCallback != null ? () => workTapCallback('인건비') : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 70),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Column(
            children: [
              const Text('인건비', style: mediumStyle),
              Text(getPrice(price: workCost), style: workerStyle),
            ],
          ),
        ),
      ),
    );
    categoryRows.add(
      InkWell(
        onTap: materialTapCallback != null
            ? () => materialTapCallback('자재비')
            : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 70),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Column(
            children: [
              const Text('자재비', style: mediumStyle),
              Text(getPrice(price: materialCost), style: materialStyle),
            ],
          ),
        ),
      ),
    );
    categoryRows.add(
      InkWell(
        onTap:
            notPayTapCallback != null ? () => notPayTapCallback('미지급') : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 70),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Column(
            children: [
              const Text('미지급', style: mediumStyle),
              Text(getPrice(price: notPayCost), style: paymentStyle),
            ],
          ),
        ),
      ),
    );

    categoryRows.add(IconButton(
        onPressed: () => showModalBottomSheet<void>(
              context: context,
              elevation: 0,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              builder: (sheetContext) => Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      '카테고리 선택',
                      style: bigStyle,
                    ),
                  ),
                  Expanded(
                      child: ListView(
                    shrinkWrap: true,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: Builder(
                          builder: (ctx) {
                            List<Map<String, dynamic>> sortedList = [];
                            for (var category in categoryList) {
                              int price = 0;
                              for (var totalCost in totalCostList) {
                                if (totalCost.category == category) {
                                  price += totalCost.price;
                                }
                              }
                              sortedList
                                  .add({'category': category, 'price': price});
                            }
                            sortedList.sort(
                                (a, b) => b['price'].compareTo(a['price']));

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                childAspectRatio: 2 / 1,
                                crossAxisCount: 3,
                              ),
                              itemCount: sortedList.length,
                              itemBuilder: (ctx, index) {
                                final category = sortedList[index]['category'];
                                final price = sortedList[index]['price'];
                                final callback = categoryTapCallbacks[category];

                                return InkWell(
                                  onTap: callback != null
                                      ? () {
                                          callback(category);
                                          Navigator.of(sheetContext).pop();
                                        }
                                      : null,
                                  child: Card(
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            category,
                                            style: normalStyle,
                                          ),
                                          Text(
                                            getPrice(price: price),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  )),
                ],
              ),
            ),
        icon: const Icon(Icons.add)));
    return categoryRows;
  }
}
