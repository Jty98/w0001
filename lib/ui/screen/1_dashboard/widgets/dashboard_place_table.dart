import 'package:flutter/material.dart';
import 'package:w0001/data/model/dashboard_models.dart';
import 'package:w0001/util/funtions.dart';

/// 현장별 공사금액·수금·이익(공사−원가)·이익률·미수금 요약.
class DashboardPlaceTable extends StatelessWidget {
  const DashboardPlaceTable({super.key, required this.places});

  final List<DashboardPlaceRow> places;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (places.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('표시할 현장이 없습니다.'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 56,
        columnSpacing: 16,
        headingTextStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: cs.primary,
        ),
        columns: const [
          DataColumn(label: Text('현장')),
          DataColumn(label: Text('공사금액'), numeric: true),
          DataColumn(label: Text('수금'), numeric: true),
          DataColumn(label: Text('이익(공사−원가)'), numeric: true),
          DataColumn(label: Text('이익률'), numeric: true),
          DataColumn(label: Text('미수금'), numeric: true),
        ],
        rows: places.map((p) {
          final margin = p.marginOnContractPct;
          return DataRow(
            cells: [
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    p.pname,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ),
              DataCell(Text(getPrice(price: p.contractTotal))),
              DataCell(Text(getPrice(price: p.collected))),
              DataCell(Text(getPrice(price: p.profitOnContract))),
              DataCell(Text(p.contractTotal > 0
                  ? '${margin.toStringAsFixed(1)}%'
                  : '—')),
              DataCell(Text(getPrice(price: p.outstanding))),
            ],
          );
        }).toList(),
      ),
    );
  }
}
