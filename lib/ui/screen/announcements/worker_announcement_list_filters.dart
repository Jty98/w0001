import 'dart:async' show Timer;

import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/place/places_api.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/domain/cost_place_picker_filter.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/ui/widget/app_sliding_segment.dart';
import 'package:w0001/ui/widget/app_text_field.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show placeUseCaseProvider;
import 'package:w0001/presentation/viewmodel/worker_announcement_paged_list_notifier.dart';
import 'package:w0001/ui/screen/announcements/worker_announcements_inbox_screen.dart';
import 'package:w0001/theme/app_input_styles.dart';
import 'package:w0001/util/responsive_layout.dart';

const _kPlaceSearchDebounceMs = 350;
const _kPlaceSuggestionLimit = 8;

/// [PlaceState] → 서버 `pcomplete` (0=진행, 1=완료).
int pcompleteForPlaceState(PlaceState state) {
  return state == PlaceState.complete ? 1 : 0;
}

CostPlacePickerFilter pickerFilterForPlaceState(PlaceState state) {
  return state == PlaceState.complete
      ? CostPlacePickerFilter.completed
      : CostPlacePickerFilter.inProgress;
}

/// 목록에 나타난 현장 pid만 이름·pcomplete 조회 (전체 현장 목록 로드 방지).
class WorkerAnnouncementPlaceNameResolver {
  final Map<int, String> _names = {};
  final Map<int, int> _pcompleteByPid = {};
  final Set<int> _loading = {};

  Map<int, String> get names => Map.unmodifiable(_names);

  int? pcompleteFor(int pid) => _pcompleteByPid[pid];

  String labelFor(int pid) =>
      _names[pid]?.trim().isNotEmpty == true ? _names[pid]! : '현장 #$pid';

  Future<void> ensureForAnnouncements(
    Iterable<WorkerAnnouncementRead> items,
  ) async {
    final missing = <int>{};
    for (final a in items) {
      final pid = a.pid;
      if (pid == null || pid <= 0) continue;
      final placeName = a.placeName?.trim() ?? '';
      if (placeName.isNotEmpty) {
        _names[pid] = placeName;
      }
      if (a.placePcomplete == 0 || a.placePcomplete == 1) {
        _pcompleteByPid[pid] = a.placePcomplete!;
      }
      if (_loading.contains(pid)) continue;
      if (_names.containsKey(pid) && _pcompleteByPid.containsKey(pid)) continue;
      missing.add(pid);
    }
    if (missing.isEmpty) return;

    _loading.addAll(missing);
    try {
      final api = PlacesRemoteApi(AppHttpClient.I);
      await Future.wait(
        missing.map((pid) async {
          try {
            final p = await api.get(pid);
            final name = p.pname.trim();
            if (name.isNotEmpty) _names[pid] = name;
            if (p.pcomplete == 0 || p.pcomplete == 1) {
              _pcompleteByPid[pid] = p.pcomplete;
            }
          } catch (_) {}
        }),
      );
    } finally {
      for (final pid in missing) {
        _loading.remove(pid);
      }
    }
  }

  void remember(int pid, String name, {int? pcomplete}) {
    final t = name.trim();
    if (pid > 0 && t.isNotEmpty) _names[pid] = t;
    if (pcomplete == 0 || pcomplete == 1) {
      _pcompleteByPid[pid] = pcomplete!;
    }
  }
}

/// 현장공지 탭 — 진행/완료와 맞지 않는 항목 제거 (서버·캐시 보정).
List<WorkerAnnouncementRead> filterAnnouncementsForPlaceTab({
  required List<WorkerAnnouncementRead> items,
  required WorkerAnnouncementInboxSegment segment,
  required PlaceState placeState,
  WorkerAnnouncementPlaceNameResolver? resolver,
}) {
  if (segment != WorkerAnnouncementInboxSegment.placeOnly) return items;
  final want = pcompleteForPlaceState(placeState);
  return items.where((a) {
    if (a.isGlobal) return false;
    final pid = a.pid;
    if (pid == null || pid <= 0) return false;
    final pc = a.placePcomplete ?? resolver?.pcompleteFor(pid);
    // 일부 응답은 pcomplete를 내려주지 않는다.
    // 이 경우 사용자에게 항목을 숨기지 않고 노출해 검색 결과와의 불일치를 방지한다.
    if (pc == null) return true;
    return pc == want;
  }).toList(growable: false);
}

/// 전체공지 / 현장공지 — [WorkerAnnouncementPlaceCompleteSegment]와 동일 스타일.
class WorkerAnnouncementInboxScopeSegment extends StatelessWidget {
  const WorkerAnnouncementInboxScopeSegment({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final WorkerAnnouncementInboxSegment value;
  final ValueChanged<WorkerAnnouncementInboxSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSlidingSegment<WorkerAnnouncementInboxSegment>(
      value: value,
      onChanged: onChanged,
      children: const {
        WorkerAnnouncementInboxSegment.globalOnly: Text('전체공지'),
        WorkerAnnouncementInboxSegment.placeOnly: Text('현장공지'),
      },
    );
  }
}

/// 현장공지 탭 — 진행중/완료 (현장 관리 탭과 동일 패턴).
class WorkerAnnouncementPlaceCompleteSegment extends StatelessWidget {
  const WorkerAnnouncementPlaceCompleteSegment({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PlaceState value;
  final ValueChanged<PlaceState> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSlidingSegment<PlaceState>(
      value: value,
      dense: true,
      onChanged: onChanged,
      children: const {
        PlaceState.incomplete: Text('진행중'),
        PlaceState.complete: Text('완료'),
      },
    );
  }
}

/// 현장공지 탭 — 현장명 검색 (선택 시 해당 현장 공지만).
class WorkerAnnouncementPlaceSearchBar extends ConsumerStatefulWidget {
  const WorkerAnnouncementPlaceSearchBar({
    super.key,
    required this.selectedPlaceId,
    required this.selectedPlaceName,
    required this.placeState,
    required this.onChanged,
  });

  final int? selectedPlaceId;
  final String? selectedPlaceName;
  final PlaceState placeState;
  final void Function(int? placeId, String? placeName, int? placePcomplete)
      onChanged;

  @override
  ConsumerState<WorkerAnnouncementPlaceSearchBar> createState() =>
      _WorkerAnnouncementPlaceSearchBarState();
}

class _WorkerAnnouncementPlaceSearchBarState
    extends ConsumerState<WorkerAnnouncementPlaceSearchBar> {
  late final TextEditingController _queryCtrl;
  Timer? _debounce;
  var _searching = false;
  var _showSuggestions = false;
  List<PlaceModel> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController(text: _displayText);
  }

  @override
  void didUpdateWidget(WorkerAnnouncementPlaceSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.placeState != oldWidget.placeState) {
      _resetQuery();
      return;
    }
    if (widget.selectedPlaceId == null && oldWidget.selectedPlaceId != null) {
      _queryCtrl.clear();
      _clearSuggestions();
      return;
    }
    if (widget.selectedPlaceId != null &&
        widget.selectedPlaceName != oldWidget.selectedPlaceName) {
      _queryCtrl.text = widget.selectedPlaceName?.trim() ?? '';
      _clearSuggestions();
    }
  }

  String get _displayText {
    final selected = widget.selectedPlaceName?.trim();
    if (widget.selectedPlaceId != null &&
        selected != null &&
        selected.isNotEmpty) {
      return selected;
    }
    return '';
  }

  void _resetQuery() {
    _debounce?.cancel();
    _queryCtrl.clear();
    _clearSuggestions();
  }

  void _clearSuggestions() {
    setState(() {
      _suggestions = const [];
      _showSuggestions = false;
      _searching = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      _clearSuggestions();
      if (widget.selectedPlaceId != null) {
        widget.onChanged(null, null, null);
      }
      return;
    }

    setState(() => _searching = true);
    try {
      final role = ref.read(authSessionProvider).asData?.value?.role;
      final filter = pickerFilterForPlaceState(widget.placeState);
      final page =
          await ref.read(placeUseCaseProvider).fetchPlacesForCostPickerPage(
                query: ListQuery(
                  pcomplete: filter.pcompleteQuery,
                  q: q,
                  limit: _kPlaceSuggestionLimit,
                ),
                filter: filter,
                role: role,
              );
      if (!mounted) return;
      setState(() {
        _suggestions = page.items;
        _showSuggestions = true;
        _searching = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _searching = false;
          _showSuggestions = true;
          _suggestions = const [];
        });
      }
    }
  }

  void _onQueryChanged(String value) {
    if (widget.selectedPlaceId != null) {
      widget.onChanged(null, null, null);
    }
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: _kPlaceSearchDebounceMs),
      () => _runSearch(value),
    );
  }

  void _pickPlace(PlaceModel place) {
    final pid = place.pid;
    if (pid == null || pid <= 0) return;
    final name = place.pname.trim();
    _queryCtrl.text = name;
    _clearSuggestions();
    widget.onChanged(pid, name, place.pcomplete);
    FocusScope.of(context).unfocus();
  }

  void _clearAll() {
    _resetQuery();
    widget.onChanged(null, null, null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasQuery = _queryCtrl.text.trim().isNotEmpty;
    final showClear = hasQuery || widget.selectedPlaceId != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rsi(16),
        0,
        context.rsi(16),
        context.rsi(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _queryCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '현장명 검색',
              isDense: true,
              prefixIcon: Icon(Icons.search_rounded, size: context.rsi(22)),
              suffixIcon: _searching
                  ? Padding(
                      padding: EdgeInsets.all(context.rsi(12)),
                      child: SizedBox(
                        width: context.rs(18),
                        height: context.rs(18),
                        child: const HammerLoadingIndicator(size: 24),
                      ),
                    )
                  : showClear
                      ? IconButton(
                          tooltip: '지우기',
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: _clearAll,
                        )
                      : null,
              filled: true,
              fillColor: cs.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.rs(12)),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.rs(12)),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.rs(12)),
                borderSide: BorderSide(
                  color: cs.primary.withValues(alpha: 0.55),
                ),
              ),
            ),
            style: AppInputStyles.fieldText(context),
            onChanged: _onQueryChanged,
            onSubmitted: _runSearch,
          ),
          if (_showSuggestions && _queryCtrl.text.trim().isNotEmpty) ...[
            SizedBox(height: context.rsi(6)),
            if (_suggestions.isEmpty && !_searching)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.rsi(4)),
                child: Text(
                  '검색 결과가 없습니다.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              )
            else
              Material(
                color: cs.surfaceContainerLow,
                elevation: 1,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(context.rs(12)),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: context.rs(220)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                    itemBuilder: (context, index) {
                      final place = _suggestions[index];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          place.pname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () => _pickPlace(place),
                      );
                    },
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

WorkerAnnouncementPagedScopeFilter scopeFilterForSegment(
  WorkerAnnouncementInboxSegment segment, {
  required WorkerAnnouncementPagedSource source,
  int? placeId,
}) {
  if (placeId != null && placeId > 0) {
    return WorkerAnnouncementPagedScopeFilter.placeOnly;
  }
  return switch (segment) {
    WorkerAnnouncementInboxSegment.globalOnly =>
      WorkerAnnouncementPagedScopeFilter.globalOnly,
    WorkerAnnouncementInboxSegment.placeOnly =>
      WorkerAnnouncementPagedScopeFilter.placeOnly,
  };
}

int? placeCompleteForPagedQuery({
  required WorkerAnnouncementInboxSegment segment,
  required PlaceState placeState,
  int? placeId,
}) {
  if (segment != WorkerAnnouncementInboxSegment.placeOnly && placeId == null) {
    return null;
  }
  return pcompleteForPlaceState(placeState);
}
