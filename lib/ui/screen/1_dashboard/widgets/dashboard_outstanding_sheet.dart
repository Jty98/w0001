import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/dashboard_models.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/util/funtions.dart';

/// 미수금이 남아 있는 현장 목록 (금액 내림차순).
void showDashboardOutstandingSheet(
  BuildContext context, {
  required List<DashboardPlaceRow> places,
}) {
  final list = places.where((p) => p.outstanding > 0).toList()
    ..sort((a, b) => b.outstanding.compareTo(a.outstanding));

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _DashboardOutstandingSheetBody(rows: list),
  );
}

class _DashboardOutstandingSheetBody extends ConsumerWidget {
  const _DashboardOutstandingSheetBody({required this.rows});

  final List<DashboardPlaceRow> rows;

  static PlaceInfoModel? _placeForPid(WidgetRef ref, int pid) {
    for (final p in ref.read(placeListProvider).placeList) {
      if (p.pid == pid) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final maxH = MediaQuery.sizeOf(context).height * 0.55;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '미수금 있는 현장',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 4),
          Text(
            rows.isEmpty
                ? '미수금이 없습니다.'
                : '총 ${rows.length}곳 · 탭하면 현장 상세로 이동합니다.',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: maxH,
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      '미수금 잔액이 0인 현장만 있습니다.',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                    itemBuilder: (ctx, i) {
                      final r = rows[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        leading: Icon(
                          Icons.request_quote_outlined,
                          color: Colors.deepPurple[700],
                        ),
                        title: Text(
                          r.pname,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '미수금 ${getPrice(price: r.outstanding)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: cs.primary,
                              ),
                            ),
                            Text(
                              '공사 ${getPrice(price: r.contractTotal)} · 수금 ${getPrice(price: r.collected)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Icon(
                          Icons.chevron_right,
                          color: cs.onSurfaceVariant,
                        ),
                        onTap: () {
                          final info = _placeForPid(ref, r.pid);
                          Navigator.of(context).pop();
                          if (info != null) {
                            context.push('/place/detail', extra: info);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('현장 목록을 불러온 뒤 다시 시도해 주세요.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
