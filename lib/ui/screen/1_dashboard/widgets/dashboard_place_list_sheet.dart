import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

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

class _DashboardPlaceListSheetBody extends ConsumerStatefulWidget {
  const _DashboardPlaceListSheetBody({required this.filter});

  final PlaceState filter;

  @override
  ConsumerState<_DashboardPlaceListSheetBody> createState() =>
      _DashboardPlaceListSheetBodyState();
}

class _DashboardPlaceListSheetBodyState
    extends ConsumerState<_DashboardPlaceListSheetBody> {
  List<PlaceInfoModel> _allPlaces = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadPlaces());
    });
  }

  Future<void> _loadPlaces() async {
    final user = ref.read(authSessionProvider).asData?.value;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final all = await ref.read(placeUseCaseProvider).getAllPlaces(
            managementPlacesInfoFirst: user.isManagementRole,
            role: user.role,
          );
      if (!mounted) return;
      setState(() {
        _allPlaces = all;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final wantComplete = widget.filter == PlaceState.complete;
    final list =
        _allPlaces.where((p) => p.pcomplete == (wantComplete ? 1 : 0)).toList();

    final title = wantComplete ? '완료 현장' : '진행 중 현장';
    final emptyLabel = wantComplete ? '완료된 현장이 없습니다.' : '진행 중인 현장이 없습니다.';
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
            title,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: context.rsi(4)),
          Text(
            '총 ${list.length}곳 · 탭하면 현장 상세로 이동합니다.',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.rsi(12)),
          SizedBox(
            height: maxH,
            child: _loading
                ? const AppLoadingIndicator()
                : list.isEmpty
                    ? Center(
                        child: Text(
                          emptyLabel,
                          style: tt.bodyMedium?.copyWith(
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
    final tt = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: context.rsi(4),
        vertical: context.rsi(2),
      ),
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
        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '공사 ${getPrice(price: place.pcontractTotal)}',
        style: tt.labelSmall?.copyWith(
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
