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
                : '총 ${rows.length}곳 · 탭하면 수금 관리로 이동합니다.',
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
                      return Material(
                        color: cs.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            final info = _placeForPid(ref, r.pid);
                            Navigator.of(context).pop();
                            if (info != null) {
                              context.push('/place/detail/revenue', extra: info);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('현장 목록을 불러온 뒤 다시 시도해 주세요.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              r.pname,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 8),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: cs.primaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                getPrice(price: r.outstanding),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: cs.onPrimaryContainer,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerHighest
                                              .withValues(alpha: 0.45),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: cs.outlineVariant
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            _infoRow(
                                              cs,
                                              text:
                                                  '공사 ${getPrice(price: r.contractTotal)}',
                                            ),
                                            const SizedBox(height: 6),
                                            _infoRow(
                                              cs,
                                              text:
                                                  '수금 ${getPrice(price: r.collected)}',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: cs.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ColorScheme cs, {required String text}) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
