import 'package:flutter/material.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';

class TotalCostCard extends StatelessWidget {
  final String category;
  final String name;
  final int price;
  final int? wcomplete;
  const TotalCostCard({
    super.key,
    required this.category,
    required this.name,
    required this.price,
    this.wcomplete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey.withOpacity(0.07),
      child: ListTile(
        leading: Text(
          category == 'w' ? '인건비' : '자재비',
          style: TextStyle(
            color: category == 'w' ? Colors.blue[700] : Colors.green[700],
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        title: Row(
          children: [
            Text(
              category != 'w'
                  ? '[$category] '
                  : (wcomplete == 0)
                      ? '[X] '
                      : '',
              style: category == 'w'
                  ? notPayStyle
                  : categoryStyle,
            ),
            Expanded(
              child: Text(
                name,
              ),
            ),
          ],
        ),
        trailing: Text(
          getPrice(price: price),
          style: TextStyle(
              fontSize: 16, color: (wcomplete == 0) ? Colors.red : null),
        ),
      ),
    );
  }
}
