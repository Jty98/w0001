import 'dart:async' show Timer;

import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/ui/widget/app_text_field.dart';
import 'package:w0001/data/model/paged_result.dart' show mergePagedItems;
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/domain/cost_place_picker_filter.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show placeUseCaseProvider;
import 'package:w0001/ui/widget/paged_list_footer.dart';
import 'package:w0001/util/responsive_layout.dart';

const _kCostPickerPageSize = kListPageSize;
const _kSearchDebounceMs = 350;

String placeCostPickerDisplayLabel(
  PlaceModel place, {
  required CostPlacePickerFilter filter,
}) {
  if (filter != CostPlacePickerFilter.all) return place.pname;
  return place.pcomplete == 1 ? '${place.pname} (완료)' : place.pname;
}

String placeCostPickerEmptyMessage(CostPlacePickerFilter filter) {
  switch (filter) {
    case CostPlacePickerFilter.all:
      return '등록된 현장이 없습니다.';
    case CostPlacePickerFilter.inProgress:
      return '진행중인 현장이 없습니다.';
    case CostPlacePickerFilter.completed:
      return '완료된 현장이 없습니다.';
  }
}

/// 금액 추가 — 현장 검색·페이지 선택 바텀시트.
Future<PlaceModel?> showPlaceCostPickerSheet({
  required BuildContext context,
  required WidgetRef ref,
  required CostPlacePickerFilter filter,
  int? selectedPid,
}) {
  return showModalBottomSheet<PlaceModel>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => PlaceCostPickerSheet(
      filter: filter,
      selectedPid: selectedPid,
    ),
  );
}

class PlaceCostPickerSheet extends ConsumerStatefulWidget {
  const PlaceCostPickerSheet({
    super.key,
    required this.filter,
    this.selectedPid,
  });

  final CostPlacePickerFilter filter;
  final int? selectedPid;

  @override
  ConsumerState<PlaceCostPickerSheet> createState() =>
      _PlaceCostPickerSheetState();
}

class _PlaceCostPickerSheetState extends ConsumerState<PlaceCostPickerSheet> {
  late final TextEditingController _queryCtrl;
  Timer? _debounce;
  Future<void>? _loadMoreInFlight;
  ScrollController? _listScrollController;

  var _query = '';
  var _loading = false;
  var _loadingMore = false;
  var _hasLoadedOnce = false;
  var _hasMore = false;
  String? _nextCursor;
  int? _totalCount;
  List<PlaceModel> _places = [];

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _scheduleLoadMoreCheck() {
    final ctrl = _listScrollController;
    if (ctrl == null) return;
    schedulePagedScrollNearEndCheck(ctrl, onLoadMore: _loadMore);
  }

  ListQuery _buildQuery({String? cursor}) {
    final q = _query.trim();
    return ListQuery(
      pcomplete: widget.filter.pcompleteQuery,
      q: q.isEmpty ? null : q,
      limit: _kCostPickerPageSize,
      cursor: cursor,
    );
  }

  Future<void> _refresh() async {
    _loadMoreInFlight = null;
    setState(() {
      _loading = true;
      _hasMore = false;
      _nextCursor = null;
    });
    try {
      final role = ref.read(authSessionProvider).asData?.value?.role;
      final page =
          await ref.read(placeUseCaseProvider).fetchPlacesForCostPickerPage(
                query: _buildQuery(),
                filter: widget.filter,
                role: role,
              );
      if (!mounted) return;
      setState(() {
        _places = page.items;
        _hasMore = page.canLoadMore;
        _nextCursor = page.nextCursor;
        _totalCount = page.totalCount;
        _loading = false;
        _hasLoadedOnce = true;
      });
      _scheduleLoadMoreCheck();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasLoadedOnce = true;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _nextCursor == null) return;
    if (_loadMoreInFlight != null) return;
    final cursor = _nextCursor!.trim();
    if (cursor.isEmpty) return;

    setState(() => _loadingMore = true);
    final future = _fetchAppend(cursor);
    _loadMoreInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_loadMoreInFlight, future)) {
        _loadMoreInFlight = null;
      }
    }
  }

  Future<void> _fetchAppend(String cursor) async {
    try {
      final role = ref.read(authSessionProvider).asData?.value?.role;
      final page =
          await ref.read(placeUseCaseProvider).fetchPlacesForCostPickerPage(
                query: _buildQuery(cursor: cursor),
                filter: widget.filter,
                role: role,
              );
      if (!mounted) return;
      setState(() {
        _places = mergePagedItems(_places, page.items, (p) => p.pid);
        _hasMore = page.canLoadMore;
        _nextCursor = page.nextCursor;
        _totalCount = page.totalCount ?? _totalCount;
        _loadingMore = false;
      });
      _scheduleLoadMoreCheck();
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: _kSearchDebounceMs),
      _refresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final countLabel = _totalCount != null
        ? '${_places.length} / $_totalCount'
        : '${_places.length}개';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (ctx, sheetScrollController) {
        _listScrollController = sheetScrollController;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.rsi(20),
                context.rsi(4),
                context.rsi(20),
                context.rsi(4),
              ),
              child: Text(
                '현장 선택',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.rsi(16)),
              child: AppTextField(
                controller: _queryCtrl,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _refresh(),
                decoration: InputDecoration(
                  hintText: '현장명으로 검색',
                  isDense: true,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _loading
                      ? Padding(
                          padding: EdgeInsets.all(context.rsi(12)),
                          child: SizedBox(
                            width: context.rs(18),
                            height: context.rs(18),
                            child: const HammerLoadingIndicator(size: 24),
                          ),
                        )
                      : IconButton(
                          tooltip: '검색',
                          icon: const Icon(Icons.search_rounded),
                          onPressed: _refresh,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: cs.primary.withValues(alpha: 0.65)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.rsi(20),
                context.rsi(10),
                context.rsi(20),
                context.rsi(6),
              ),
              child: Text(
                _hasLoadedOnce && !_loading ? countLabel : '현장을 불러오는 중…',
                style: tt.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: _buildList(context, sheetScrollController, bottom),
            ),
          ],
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    ScrollController sheetScrollController,
    double bottom,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_loading && !_hasLoadedOnce) {
      return const AppLoadingIndicator();
    }
    if (_hasLoadedOnce && _places.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.rsi(28)),
          child: Text(
            _query.trim().isNotEmpty
                ? '검색 결과가 없습니다.'
                : placeCostPickerEmptyMessage(widget.filter),
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        onPagedScrollNearEnd(sheetScrollController, onLoadMore: _loadMore);
        return false;
      },
      child: ListView.builder(
        controller: sheetScrollController,
        padding: EdgeInsets.fromLTRB(
          context.rsi(16),
          0,
          context.rsi(16),
          bottom + context.rsi(8),
        ),
        itemCount: _places.length + 1,
        itemBuilder: (ctx, i) {
          if (i >= _places.length) {
            return PagedListFooter(
              isLoading: _loadingMore,
              hasMore: _hasMore,
            );
          }
          final place = _places[i];
          final selected = place.pid != null && place.pid == widget.selectedPid;
          final label = placeCostPickerDisplayLabel(
            place,
            filter: widget.filter,
          );
          final subtitle = place.paddress.trim();
          return Padding(
            padding: EdgeInsets.only(bottom: context.rsi(8)),
            child: Material(
              color: selected
                  ? cs.primaryContainer.withValues(alpha: 0.42)
                  : cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: selected
                      ? cs.primary.withValues(alpha: 0.45)
                      : cs.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.pop(context, place),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rsi(14),
                    vertical: context.rsi(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.home_work_outlined,
                        color: cs.onSurfaceVariant,
                        size: context.rs(22),
                      ),
                      SizedBox(width: context.rsi(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle.isNotEmpty) ...[
                              SizedBox(height: context.rsi(2)),
                              Text(
                                subtitle,
                                style: tt.labelMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle_rounded, color: cs.primary)
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
