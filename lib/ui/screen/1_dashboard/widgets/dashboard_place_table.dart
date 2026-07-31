import 'package:flutter/material.dart';
import 'package:w0001/data/model/dashboard_models.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 현장별 공사금액·수금·이익(공사−원가)·이익률·미수금 요약.
class DashboardPlaceTable extends StatelessWidget {
  const DashboardPlaceTable({super.key, required this.places});

  final List<DashboardPlaceRow> places;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (places.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(context.rsi(16)),
        child: const Text('표시할 현장이 없습니다.'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: context.rs(40),
        dataRowMinHeight: context.rs(44),
        dataRowMaxHeight: context.rs(56),
        columnSpacing: context.rsi(16),
        headingTextStyle: tt.labelSmall?.copyWith(
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
                  constraints: BoxConstraints(maxWidth: context.rs(140)),
                  child: Text(
                    p.pname,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: tt.bodyMedium,
                  ),
                ),
              ),
              DataCell(Text(getPrice(price: p.contractTotal))),
              DataCell(Text(getPrice(price: p.collected))),
              DataCell(Text(getPrice(price: p.profitOnContract))),
              DataCell(Text(
                p.contractTotal > 0 ? '${margin.toStringAsFixed(1)}%' : '—',
              )),
              DataCell(Text(getPrice(price: p.outstanding))),
            ],
          );
        }).toList(),
      ),
    );
  }
}
