import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/domain/place_delete_error.dart';
import 'package:w0001/domain/place_work_period_display.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_delete_options_dialog.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 설정 — 숨김(보관) 현장 복구·영구삭제.
class ArchivedPlacesManagementScreen extends ConsumerStatefulWidget {
  const ArchivedPlacesManagementScreen({super.key});

  @override
  ConsumerState<ArchivedPlacesManagementScreen> createState() =>
      _ArchivedPlacesManagementScreenState();
}

class _ArchivedPlacesManagementScreenState
    extends ConsumerState<ArchivedPlacesManagementScreen> {
  final _items = <PlaceInfoModel>[];
  var _loading = true;
  String? _error;
  String? _nextCursor;
  var _hasMore = false;
  var _loadingMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = ref.read(authSessionProvider).asData?.value;
      final page = await ref.read(placeUseCaseProvider).fetchPlacesPage(
            query: const ListQuery(pcomplete: 2, limit: 40),
            managementPlacesInfoFirst: true,
            role: user?.role,
          );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasMore = page.canLoadMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '보관 현장을 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _nextCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final user = ref.read(authSessionProvider).asData?.value;
      final page = await ref.read(placeUseCaseProvider).fetchPlacesPage(
            query: ListQuery(
              pcomplete: 2,
              limit: 40,
              cursor: _nextCursor,
            ),
            managementPlacesInfoFirst: true,
            role: user?.role,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasMore = page.canLoadMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _restore(PlaceInfoModel place, int toPcomplete) async {
    final pid = place.pid;
    if (pid == null) return;
    final endDate = pendWhenTogglingToComplete(place);
    try {
      await ref.read(placeUseCaseProvider).updatePlaceCompletionStatus(
            pid,
            toPcomplete,
            endDate,
          );
      await FetchData.onDataChanged(DataChangeEvent.placeSaved);
      ref.read(addCostProvider.notifier).clearSelectedPlace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            toPcomplete == 0 ? '진행중으로 복구했습니다.' : '완료로 복구했습니다.',
          ),
        ),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userMessageForPlaceDeleteFailure(e))),
      );
    }
  }

  Future<void> _confirmRestore(PlaceInfoModel place) async {
    final choice = await showDialog<int>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('현장 복구'),
        content: Text(
          '\'${place.pname}\' 현장을 다시 현장 관리 목록에 보이게 합니다.\n어느 상태로 복구할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(0),
            child: const Text('진행중'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(1),
            child: const Text('완료'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    await _restore(place, choice);
  }

  Future<void> _delete(PlaceInfoModel place) async {
    final pid = place.pid;
    if (pid == null) return;
    await showPlaceDeleteOptionsDialog(
      context: context,
      placeName: place.pname,
      permanentOnly: true,
      onDelete: ({required bool permanent}) async {
        await ref.read(placeUseCaseProvider).deletePlace(
              pid,
              permanent: permanent,
            );
        await FetchData.onDataChanged(DataChangeEvent.placeSaved);
        ref.read(addCostProvider.notifier).clearSelectedPlace();
      },
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('보관 현장'),
      ),
      body: SafeArea(
        child: AppRefreshIndicator(
          onRefresh: _reload,
          child: _loading
              ? const Center(child: HammerLoadingIndicator(size: 48))
              : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: context.rsi(80)),
                        Center(
                          child: Text(
                            _error!,
                            style: tt.bodyLarge,
                          ),
                        ),
                        SizedBox(height: context.rsi(16)),
                        Center(
                          child: FilledButton(
                            onPressed: _reload,
                            child: const Text('다시 불러오기'),
                          ),
                        ),
                      ],
                    )
                  : _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(context.rsi(24)),
                          children: [
                            SizedBox(height: context.rsi(60)),
                            Icon(
                              Icons.inventory_2_outlined,
                              size: context.rsi(48),
                              color: cs.onSurfaceVariant,
                            ),
                            SizedBox(height: context.rsi(16)),
                            Text(
                              '숨긴 현장이 없습니다.',
                              textAlign: TextAlign.center,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: context.rsi(8)),
                            Text(
                              '현장 관리에서 「목록에서 숨기기」한 현장이 여기에 모입니다.\n복구하면 진행중·완료 목록에 다시 나타납니다.',
                              textAlign: TextAlign.center,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            context.rsi(16),
                            context.rsi(12),
                            context.rsi(16),
                            context.rsi(24),
                          ),
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              SizedBox(height: context.rsi(8)),
                          itemBuilder: (context, index) {
                            if (index >= _items.length) {
                              if (!_loadingMore) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) => _loadMore());
                              }
                              return Padding(
                                padding: EdgeInsets.all(context.rsi(12)),
                                child: const Center(
                                  child: HammerLoadingIndicator(size: 32),
                                ),
                              );
                            }
                            final place = _items[index];
                            final period = buildPlaceListPeriodLabels(
                              place: place,
                              contractPendIso: null,
                              includeAdditionalWork: false,
                            );
                            return Card(
                              elevation: 0,
                              color: cs.surfaceContainerLow,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(context.rsi(12)),
                                side: BorderSide(
                                  color: cs.outlineVariant.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  context.rsi(14),
                                  context.rsi(12),
                                  context.rsi(8),
                                  context.rsi(10),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      place.pname,
                                      style: tt.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: context.rsi(4)),
                                    Text(
                                      period.contractPeriodLine,
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    if (place.paddress.trim().isNotEmpty) ...[
                                      SizedBox(height: context.rsi(2)),
                                      Text(
                                        place.paddress.trim(),
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    SizedBox(height: context.rsi(10)),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton.tonal(
                                            onPressed: () =>
                                                _confirmRestore(place),
                                            child: const Text('복구'),
                                          ),
                                        ),
                                        SizedBox(width: context.rsi(8)),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => _delete(place),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: cs.error,
                                            ),
                                            child: const Text('삭제'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}
