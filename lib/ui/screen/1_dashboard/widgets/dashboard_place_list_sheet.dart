import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/util/funtions.dart';

/// 진행 중 / 완료 현장 목록 (현장 관리 탭과 동일 필터, 바텀시트).
void showDashboardPlaceListSheet(
  BuildContext context, {
  required PlaceState filter,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _DashboardPlaceListSheetBody(filter: filter),
  );
}

class _DashboardPlaceListSheetBody extends ConsumerWidget {
  const _DashboardPlaceListSheetBody({required this.filter});

  final PlaceState filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final placeState = ref.watch(placeListProvider);
    final wantComplete = filter == PlaceState.complete;
    final list = placeState.placeList
        .where((p) => p.pcomplete == (wantComplete ? 1 : 0))
        .toList();

    final title = wantComplete ? '완료 현장' : '진행 중 현장';
    final emptyLabel =
        wantComplete ? '완료된 현장이 없습니다.' : '진행 중인 현장이 없습니다.';
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
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 4),
          Text(
            '총 ${list.length}곳 · 탭하면 현장 상세로 이동합니다.',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: maxH,
            child: list.isEmpty
                ? Center(
                    child: Text(
                      emptyLabel,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                    itemBuilder: (ctx, i) {
                      final p = list[i];
                      return _PlaceSheetTile(place: p);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlaceSheetTile extends StatelessWidget {
  const _PlaceSheetTile({required this.place});

  final PlaceInfoModel place;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Icon(
        place.pcomplete == 1
            ? Icons.check_circle_outline
            : Icons.construction_outlined,
        color: cs.primary,
      ),
      title: Text(
        place.pname,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      subtitle: Text(
        '공사 ${getPrice(price: place.pcontractTotal)}',
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      onTap: () {
        Navigator.of(context).pop();
        context.push('/place/detail', extra: place);
      },
    );
  }
}
