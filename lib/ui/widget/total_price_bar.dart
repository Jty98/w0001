import 'package:flutter/material.dart';
import 'package:w0001/data/model/calendar_day_cost_totals.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

typedef CategoryTapCallback = void Function(String category);

/// 합계 바 카테고리 금액 색 (타이포는 [TextTheme], 색만 고정 토큰).
const Color _workCostAmountColor = Color(0xFF1976D2);
const Color _materialCostAmountColor = Color(0xFF388E3C);

TextStyle? _categoryAmountStyle(
  TextTheme tt,
  Color color, {
  required bool compact,
}) {
  final base = compact ? tt.labelLarge : tt.titleMedium ?? tt.bodyLarge;
  return base?.copyWith(fontWeight: FontWeight.bold, color: color);
}

const placeCategory = ['인건비', '미지급', '자재비', '전체', ...categoryList];

class TotalPriceBar extends StatelessWidget {
  const TotalPriceBar({
    super.key,
    required this.totalCostList,
    required this.categoryTapCallbacks,
    this.compact = false,
    this.dense = false,
    this.dayTotals,
  });

  final List<TotalCostModel> totalCostList;
  final Map<String, CategoryTapCallback> categoryTapCallbacks;

  /// 서버 일자 집계 — 페이지네이션 시 하단 4칩 합계용.
  final CalendarDayCostTotals? dayTotals;

  /// 캘린더 탭 등 — 라벨·금액·패딩을 줄인 레이아웃.
  final bool compact;

  /// 캘린더 탭 — [compact]보다 더 작은 칩형 합계 바.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ultra = dense || compact;
    final dividerH = dense ? 0.0 : (compact ? 1.0 : 3.0);
    final dividerT = dense ? 0.5 : (compact ? 1.0 : 2.0);
    return Container(
      color:
          cs.secondary.withValues(alpha: dense ? 0.1 : (compact ? 0.14 : 0.18)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: dividerH, thickness: dividerT),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _buildCategoryRows(context),
            ),
          ),
          Divider(height: ultra ? 0 : 0, thickness: dividerT),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryRows(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final labelStyle =
        dense ? tt.labelSmall : (compact ? tt.labelMedium : tt.bodyMedium);
    final priceStyle = dense
        ? tt.labelMedium
        : (compact ? tt.labelLarge : tt.titleMedium ?? tt.bodyLarge);
    final priceWeight = priceStyle?.copyWith(fontWeight: FontWeight.bold);
    final itemPadding = dense
        ? ResponsiveLayout.symmetric(context, vertical: 2, horizontal: 5)
        : (compact
            ? ResponsiveLayout.symmetric(context, vertical: 5, horizontal: 8)
            : ResponsiveLayout.symmetric(context,
                vertical: 10, horizontal: 10));
    final firstPadding = dense
        ? ResponsiveLayout.only(context, left: 10, top: 2, right: 5, bottom: 2)
        : (compact
            ? ResponsiveLayout.only(context,
                left: 14, top: 5, right: 8, bottom: 5)
            : ResponsiveLayout.only(
                context,
                left: 20,
                top: 10,
                right: 10,
                bottom: 10,
              ));
    final minW = context.rs(dense ? 52 : (compact ? 60 : 70));

    Widget amountText(String price, TextStyle? style) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(price, style: style, maxLines: 1),
      );
    }

    Widget labelText(String label) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, style: labelStyle, maxLines: 1),
      );
    }

    // 위젯 담을 List
    List<Widget> categoryRows = [];

    final materialTapCallback = categoryTapCallbacks['자재비'];
    final workTapCallback = categoryTapCallbacks['인건비'];
    final notPayTapCallback = categoryTapCallbacks['미지급'];
    final totalTapCallback = categoryTapCallbacks['전체'];

    int workCost = 0;
    int materialCost = 0;
    int notPayCost = 0;

    final totals = dayTotals;
    if (totals != null) {
      workCost = totals.workAmount;
      materialCost = totals.materialAmount;
      notPayCost = totals.unpaidAmount;
    } else {
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
    }

    categoryRows.add(
      InkWell(
        onTap: totalTapCallback != null ? () => totalTapCallback('전체') : null,
        child: Container(
          constraints: BoxConstraints(minWidth: minW),
          padding: firstPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              labelText('전체'),
              amountText(
                getPrice(
                  price: totals?.totalAmount ?? workCost + materialCost,
                ),
                priceWeight,
              ),
            ],
          ),
        ),
      ),
    );

    categoryRows.add(
      InkWell(
        onTap: workTapCallback != null ? () => workTapCallback('인건비') : null,
        child: Container(
          constraints: BoxConstraints(minWidth: minW),
          padding: itemPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              labelText('인건비'),
              amountText(
                getPrice(price: workCost),
                _categoryAmountStyle(
                  tt,
                  _workCostAmountColor,
                  compact: compact || dense,
                ),
              ),
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
          constraints: BoxConstraints(minWidth: minW),
          padding: itemPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              labelText('자재비'),
              amountText(
                getPrice(price: materialCost),
                _categoryAmountStyle(
                  tt,
                  _materialCostAmountColor,
                  compact: compact || dense,
                ),
              ),
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
          constraints: BoxConstraints(minWidth: minW),
          padding: itemPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              labelText('미지급'),
              amountText(
                getPrice(price: notPayCost),
                _categoryAmountStyle(
                  tt,
                  Theme.of(context).colorScheme.error,
                  compact: compact || dense,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    categoryRows.add(IconButton(
        iconSize: context.rsi(dense ? 18 : (compact ? 20 : 24)),
        padding: (compact || dense) ? EdgeInsets.all(context.rs(2)) : null,
        constraints: (compact || dense)
            ? BoxConstraints(
                minWidth: context.rs(dense ? 28 : 32),
                minHeight: context.rs(dense ? 28 : 32),
              )
            : null,
        onPressed: () => showModalBottomSheet<void>(
              context: context,
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              builder: (sheetContext) => Column(
                children: [
                  Padding(
                    padding: ResponsiveLayout.symmetric(context, vertical: 10),
                    child: Text(
                      '카테고리 선택',
                      style: tt.titleMedium,
                    ),
                  ),
                  Expanded(
                      child: ListView(
                    shrinkWrap: true,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(context.rs(5)),
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
                                            style: tt.bodyMedium,
                                          ),
                                          Text(
                                            getPrice(price: price),
                                            style: tt.labelSmall?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
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
