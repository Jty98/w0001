import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/dashboard_models.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

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
    final tt = Theme.of(context).textTheme;
    final maxH = MediaQuery.sizeOf(context).height * 0.55;

    return Padding(
      padding: EdgeInsets.only(
        left: context.rsi(16),
        right: context.rsi(16),
        bottom: MediaQuery.paddingOf(context).bottom + context.rsi(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '미수금 있는 현장',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          rsV(context, 4),
          Text(
            rows.isEmpty
                ? '미수금이 없습니다.'
                : '총 ${rows.length}곳 · 탭하면 수금 관리로 이동합니다.',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          rsV(context, 12),
          SizedBox(
            height: maxH,
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      '미수금 잔액이 0인 현장만 있습니다.',
                      style: tt.bodyMedium?.copyWith(
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
                        borderRadius: BorderRadius.circular(context.rs(10)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(context.rs(10)),
                          onTap: () {
                            final info = _placeForPid(ref, r.pid);
                            Navigator.of(context).pop();
                            if (info != null) {
                              context.push('/place/detail/revenue',
                                  extra: info);
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
                            padding: ResponsiveLayout.only(
                              ctx,
                              left: 10,
                              top: 8,
                              right: 10,
                              bottom: 8,
                            ),
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
                                              style: tt.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: ResponsiveLayout.only(
                                              ctx,
                                              left: 8,
                                            ),
                                            child: Container(
                                              padding:
                                                  ResponsiveLayout.symmetric(
                                                ctx,
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
                                                style: tt.labelSmall?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  color: cs.onPrimaryContainer,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      rsV(ctx, 6),
                                      Container(
                                        width: double.infinity,
                                        padding: ResponsiveLayout.symmetric(
                                          ctx,
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerHighest
                                              .withValues(alpha: 0.45),
                                          borderRadius:
                                              BorderRadius.circular(context.rs(8)),
                                          border: Border.all(
                                            color: cs.outlineVariant
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            _infoRow(
                                              ctx,
                                              cs,
                                              text:
                                                  '공사 ${getPrice(price: r.contractTotal)}',
                                            ),
                                            rsV(ctx, 6),
                                            _infoRow(
                                              ctx,
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
                                rsH(ctx, 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: context.rsi(18),
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

  Widget _infoRow(
    BuildContext context,
    ColorScheme cs, {
    required String text,
  }) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: context.rs(6),
          height: context.rs(6),
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        rsH(context, 8),
        Expanded(
          child: Text(
            text,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
