import 'dart:async' show Timer;

import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/ui/widget/app_text_field.dart';
import 'package:w0001/data/model/paged_result.dart' show mergePagedItems;
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show humanUseCaseProvider;
import 'package:w0001/ui/widget/human_picker/human_picker_skill_panel.dart';
import 'package:w0001/ui/widget/paged_list_footer.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/worker_skills_display.dart';

/// 검색 가능 인력 후보 (hid 기준).
class HumanPickRow {
  const HumanPickRow({
    required this.hid,
    required this.name,
    this.subtitle = '',
    this.human,
  });

  final int hid;
  final String name;
  final String subtitle;
  final HumanModel? human;
}

/// 단일 인력 선택 바텀시트.
Future<int?> showHumanHidPickSheet({
  required BuildContext context,
  required String title,
  required List<HumanPickRow> candidates,
  int? excludeHid,
  int? selectedHid,
}) async {
  final rows = candidates
      .where((c) => excludeHid == null || c.hid != excludeHid)
      .toList();
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('선택할 인력이 없습니다.')),
    );
    return null;
  }

  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _HumanHidPickSheet(
      title: title,
      candidates: rows,
      multi: false,
      initialSelected: selectedHid != null ? {selectedHid} : {},
    ),
  );
}

/// 다중 인력 선택 바텀시트.
Future<Set<int>?> showHumanHidMultiPickSheet({
  required BuildContext context,
  required String title,
  required List<HumanPickRow> candidates,
  required Set<int> initialSelected,
  int? excludeHid,
}) async {
  final rows = candidates
      .where((c) => excludeHid == null || c.hid != excludeHid)
      .toList();
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('선택할 인력이 없습니다.')),
    );
    return null;
  }

  return showModalBottomSheet<Set<int>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _HumanHidPickSheet(
      title: title,
      candidates: rows,
      multi: true,
      initialSelected: Set<int>.from(initialSelected),
    ),
  );
}

/// 서버 검색 — 단일 hid 선택 (트러블 페어 등).
Future<int?> showHumanHidServerSearchPickSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  int? excludeHid,
}) async {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _HumanHidServerSearchPickSheet(
      title: title,
      excludeHid: excludeHid,
    ),
  );
}

/// 인력 투입 — 서버 검색 + 다중 선택.
Future<List<HumanModel>?> showWorkforceHumanMultiPickSheet({
  required BuildContext context,
  required WidgetRef ref,
  required List<HumanModel> initialSelected,
}) async {
  return showModalBottomSheet<List<HumanModel>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _WorkforceHumanMultiPickSheet(
      initialSelected: initialSelected,
    ),
  );
}

class _HumanPickSearchField extends StatelessWidget {
  const _HumanPickSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onSubmitted,
    this.loading = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppTextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        isDense: true,
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: loading
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
                onPressed: () => onSubmitted?.call(controller.text),
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
          borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.65)),
        ),
      ),
    );
  }
}

/// 인력 선택 타일 — 이름(+현장 역할) + [human]/[detail]/[subtitle].
class HumanPickPersonTile extends StatelessWidget {
  const HumanPickPersonTile({
    super.key,
    required this.name,
    this.human,
    this.subtitle = '',
    this.detail,
    this.showRrn = true,
    required this.selected,
    required this.multi,
    required this.onTap,
  });

  final String name;
  final HumanModel? human;
  final String subtitle;
  final Widget? detail;
  final bool showRrn;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final initial = name.isNotEmpty ? name[0] : '?';
    final h = human;
    final siteRank = h != null ? resolveHumanSiteRank(h)?.trim() : null;
    final hasSiteRank = siteRank != null && siteRank.isNotEmpty;
    final skillBody =
        h != null ? HumanPickerSkillPanel(human: h, showRrn: showRrn) : detail;

    return Padding(
      padding: EdgeInsets.only(bottom: context.rsi(7)),
      child: Material(
        color: selected
            ? cs.primaryContainer.withValues(alpha: 0.42)
            : cs.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected
                ? cs.primary.withValues(alpha: 0.45)
                : cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.rsi(12),
              vertical: context.rsi(9),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: context.rs(19),
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.onSecondaryContainer,
                  child: Text(
                    initial,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: context.rs(14),
                    ),
                  ),
                ),
                SizedBox(width: context.rsi(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              name,
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasSiteRank) ...[
                            SizedBox(width: context.rsi(8)),
                            HumanPickerSiteRankBadge(
                              label: siteRank,
                            ),
                          ],
                        ],
                      ),
                      if (skillBody != null) ...[
                        SizedBox(height: context.rsi(4)),
                        skillBody,
                      ] else if (subtitle.isNotEmpty) ...[
                        SizedBox(height: context.rsi(2)),
                        Text(
                          subtitle,
                          style: tt.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: context.rsi(2)),
                Padding(
                  padding: EdgeInsets.only(left: context.rsi(2)),
                  child: multi
                      ? Checkbox(
                          value: selected,
                          onChanged: (_) => onTap(),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        )
                      : selected
                          ? Icon(Icons.check_circle_rounded, color: cs.primary)
                          : Icon(
                              Icons.chevron_right_rounded,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [HumanPickPersonTile.human] 대신 하위만 쓸 때 (레거시 호환).
class HumanPickerSkillDetail extends StatelessWidget {
  const HumanPickerSkillDetail({super.key, required this.human});

  final HumanModel human;

  @override
  Widget build(BuildContext context) => HumanPickerSkillPanel(human: human);
}

class _HumanHidPickSheet extends StatefulWidget {
  const _HumanHidPickSheet({
    required this.title,
    required this.candidates,
    required this.multi,
    required this.initialSelected,
  });

  final String title;
  final List<HumanPickRow> candidates;
  final bool multi;
  final Set<int> initialSelected;

  @override
  State<_HumanHidPickSheet> createState() => _HumanHidPickSheetState();
}

class _HumanHidPickSheetState extends State<_HumanHidPickSheet> {
  late final TextEditingController _queryCtrl;
  late Set<int> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController();
    _selected = Set<int>.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<HumanPickRow> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.candidates;
    return widget.candidates
        .where((c) => c.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filtered = _filtered;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final hasQuery = _query.trim().isNotEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) {
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
                widget.title,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.rsi(16)),
              child: _HumanPickSearchField(
                controller: _queryCtrl,
                hintText: '이름으로 검색',
                onChanged: (v) => setState(() => _query = v),
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
                hasQuery ? '${filtered.length}명' : '이름을 검색해 작업자를 찾으세요',
                style: tt.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: !hasQuery
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(context.rsi(28)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_search_outlined,
                              size: context.rs(52),
                              color: cs.outline,
                            ),
                            SizedBox(height: context.rsi(12)),
                            Text(
                              '검색창을 눌러 이름을 입력하세요',
                              textAlign: TextAlign.center,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            '검색 결과가 없습니다.',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: EdgeInsets.fromLTRB(
                            context.rsi(16),
                            0,
                            context.rsi(16),
                            context.rsi(8) + bottom,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final row = filtered[i];
                            final checked = _selected.contains(row.hid);
                            return HumanPickPersonTile(
                              name: row.name,
                              human: row.human,
                              subtitle: row.human == null ? row.subtitle : '',
                              showRrn: row.human == null,
                              selected: checked,
                              multi: widget.multi,
                              onTap: () {
                                if (widget.multi) {
                                  setState(() {
                                    if (checked) {
                                      _selected.remove(row.hid);
                                    } else {
                                      _selected.add(row.hid);
                                    }
                                  });
                                } else {
                                  Navigator.pop(context, row.hid);
                                }
                              },
                            );
                          },
                        ),
            ),
            if (widget.multi)
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.rsi(16),
                    context.rsi(4),
                    context.rsi(16),
                    context.rsi(8),
                  ),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: Text('${_selected.length}명 선택 적용'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HumanHidServerSearchPickSheet extends ConsumerStatefulWidget {
  const _HumanHidServerSearchPickSheet({
    required this.title,
    this.excludeHid,
  });

  final String title;
  final int? excludeHid;

  @override
  ConsumerState<_HumanHidServerSearchPickSheet> createState() =>
      _HumanHidServerSearchPickSheetState();
}

class _HumanHidServerSearchPickSheetState
    extends ConsumerState<_HumanHidServerSearchPickSheet> {
  late final TextEditingController _queryCtrl;
  ScrollController? _attachedScroll;
  Timer? _debounce;
  Future<void>? _loadMoreInFlight;
  var _query = '';
  var _loading = false;
  var _loadingMore = false;
  var _searched = false;
  var _hasMore = false;
  String? _nextCursor;
  List<HumanModel> _results = [];

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _attachedScroll?.removeListener(_onScroll);
    _queryCtrl.dispose();
    super.dispose();
  }

  void _attachScroll(ScrollController controller) {
    if (identical(_attachedScroll, controller)) return;
    _attachedScroll?.removeListener(_onScroll);
    _attachedScroll = controller;
    controller.addListener(_onScroll);
  }

  void _onScroll() {
    final ctrl = _attachedScroll;
    if (ctrl == null) return;
    onPagedScrollNearEnd(ctrl, onLoadMore: _loadMore);
  }

  Future<void> _search({String? query, bool append = false}) async {
    final q = (query ?? _query).trim();
    if (q.isEmpty) {
      setState(() {
        _searched = false;
        _results = [];
        _loading = false;
        _loadingMore = false;
        _hasMore = false;
        _nextCursor = null;
      });
      return;
    }

    if (append) {
      if (!_hasMore || _loadingMore || _loading) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _searched = true;
        _hasMore = false;
        _nextCursor = null;
      });
    }

    try {
      final page = await ref.read(humanUseCaseProvider).searchWorkersPage(
            q: q,
            cursor: append ? _nextCursor : null,
          );
      if (!mounted) return;
      final filtered = page.items
          .where(
            (h) =>
                h.hdelete == 0 && h.hid != null && h.hid != widget.excludeHid,
          )
          .toList();
      setState(() {
        _results = append
            ? mergePagedItems(_results, filtered, (h) => h.hid)
            : filtered;
        _hasMore = page.canLoadMore;
        _nextCursor = page.nextCursor;
        _loading = false;
        _loadingMore = false;
      });
      if (!append) {
        final ctrl = _attachedScroll;
        if (ctrl != null) {
          schedulePagedScrollNearEndCheck(ctrl, onLoadMore: _loadMore);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() {
    if (_loadMoreInFlight != null) return _loadMoreInFlight!;
    _loadMoreInFlight = _search(append: true);
    return _loadMoreInFlight!.whenComplete(() => _loadMoreInFlight = null);
  }

  void _onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _searched = false;
        _results = [];
        _loading = false;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(query: q),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final hasQuery = _query.trim().isNotEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) {
        _attachScroll(scrollController);
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
                widget.title,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.rsi(16)),
              child: _HumanPickSearchField(
                controller: _queryCtrl,
                hintText: '이름으로 검색',
                loading: _loading,
                onChanged: _onQueryChanged,
                onSubmitted: (q) => _search(query: q),
              ),
            ),
            Expanded(
              child: _loading
                  ? const AppLoadingIndicator()
                  : !hasQuery || !_searched
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(context.rsi(28)),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_search_outlined,
                                  size: context.rs(52),
                                  color: cs.outline,
                                ),
                                SizedBox(height: context.rsi(12)),
                                Text(
                                  '이름을 검색해 작업자를 선택하세요',
                                  textAlign: TextAlign.center,
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                '검색 결과가 없습니다.',
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.fromLTRB(
                                context.rsi(16),
                                context.rsi(8),
                                context.rsi(16),
                                bottom + context.rsi(8),
                              ),
                              itemCount: _results.length + 1,
                              itemBuilder: (ctx, i) {
                                if (i >= _results.length) {
                                  return PagedListFooter(
                                    isLoading: _loadingMore,
                                    hasMore: _hasMore,
                                  );
                                }
                                final h = _results[i];
                                final id = h.hid!;
                                return HumanPickPersonTile(
                                  name: h.hname,
                                  human: h,
                                  selected: false,
                                  multi: false,
                                  onTap: () => Navigator.pop(context, id),
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}

class _WorkforceHumanMultiPickSheet extends ConsumerStatefulWidget {
  const _WorkforceHumanMultiPickSheet({
    required this.initialSelected,
  });

  final List<HumanModel> initialSelected;

  @override
  ConsumerState<_WorkforceHumanMultiPickSheet> createState() =>
      _WorkforceHumanMultiPickSheetState();
}

class _WorkforceHumanMultiPickSheetState
    extends ConsumerState<_WorkforceHumanMultiPickSheet> {
  late final TextEditingController _queryCtrl;
  final Map<int, HumanModel> _selectedByHid = {};
  ScrollController? _attachedScroll;
  Timer? _debounce;
  Future<void>? _loadMoreInFlight;
  var _query = '';
  var _loading = false;
  var _loadingMore = false;
  var _searched = false;
  var _hasMore = false;
  String? _nextCursor;
  List<HumanModel> _results = [];

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController();
    for (final h in widget.initialSelected) {
      final id = h.hid;
      if (id != null) _selectedByHid[id] = h;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _attachedScroll?.removeListener(_onScroll);
    _queryCtrl.dispose();
    super.dispose();
  }

  void _attachScroll(ScrollController controller) {
    if (identical(_attachedScroll, controller)) return;
    _attachedScroll?.removeListener(_onScroll);
    _attachedScroll = controller;
    controller.addListener(_onScroll);
  }

  void _onScroll() {
    final ctrl = _attachedScroll;
    if (ctrl == null) return;
    onPagedScrollNearEnd(ctrl, onLoadMore: _loadMore);
  }

  Future<void> _search({String? query, bool append = false}) async {
    final q = (query ?? _query).trim();
    if (q.isEmpty) {
      setState(() {
        _searched = false;
        _results = [];
        _loading = false;
        _loadingMore = false;
        _hasMore = false;
        _nextCursor = null;
      });
      return;
    }

    if (append) {
      if (!_hasMore || _loadingMore || _loading) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _searched = true;
        _hasMore = false;
        _nextCursor = null;
      });
    }

    try {
      final page = await ref.read(humanUseCaseProvider).searchWorkersPage(
            q: q,
            cursor: append ? _nextCursor : null,
          );
      if (!mounted) return;
      final filtered = page.items.where((h) => h.hdelete == 0).toList();
      setState(() {
        _results = append
            ? mergePagedItems(_results, filtered, (h) => h.hid)
            : filtered;
        _hasMore = page.canLoadMore;
        _nextCursor = page.nextCursor;
        _loading = false;
        _loadingMore = false;
      });
      if (!append) {
        final ctrl = _attachedScroll;
        if (ctrl != null) {
          schedulePagedScrollNearEndCheck(ctrl, onLoadMore: _loadMore);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() {
    if (_loadMoreInFlight != null) return _loadMoreInFlight!;
    _loadMoreInFlight = _search(append: true);
    return _loadMoreInFlight!.whenComplete(() => _loadMoreInFlight = null);
  }

  void _onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _searched = false;
        _results = [];
        _loading = false;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(query: q),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final hasQuery = _query.trim().isNotEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        _attachScroll(scrollController);
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
                '인력 선택',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.rsi(16)),
              child: _HumanPickSearchField(
                controller: _queryCtrl,
                hintText: '이름으로 검색',
                loading: _loading,
                onChanged: _onQueryChanged,
                onSubmitted: (q) => _search(query: q),
              ),
            ),
            if (_selectedByHid.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.rsi(16),
                  context.rsi(10),
                  context.rsi(16),
                  0,
                ),
                child: Text(
                  '선택 ${_selectedByHid.length}명',
                  style: tt.labelLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const AppLoadingIndicator()
                  : !hasQuery || !_searched
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(context.rsi(28)),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.groups_outlined,
                                  size: context.rs(52),
                                  color: cs.outline,
                                ),
                                SizedBox(height: context.rsi(12)),
                                Text(
                                  '이름을 검색해 인력을 찾으세요',
                                  textAlign: TextAlign.center,
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                '검색 결과가 없습니다.',
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.fromLTRB(
                                context.rsi(16),
                                context.rsi(8),
                                context.rsi(16),
                                bottom + context.rsi(8),
                              ),
                              itemCount: _results.length + 1,
                              itemBuilder: (ctx, i) {
                                if (i >= _results.length) {
                                  return PagedListFooter(
                                    isLoading: _loadingMore,
                                    hasMore: _hasMore,
                                  );
                                }
                                final h = _results[i];
                                final id = h.hid;
                                final checked = id != null &&
                                    _selectedByHid.containsKey(id);
                                return HumanPickPersonTile(
                                  name: h.hname,
                                  human: h,
                                  selected: checked,
                                  multi: true,
                                  onTap: () {
                                    if (id == null) return;
                                    setState(() {
                                      if (checked) {
                                        _selectedByHid.remove(id);
                                      } else {
                                        _selectedByHid[id] = h;
                                      }
                                    });
                                  },
                                );
                              },
                            ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.rsi(16),
                  context.rsi(4),
                  context.rsi(16),
                  context.rsi(8),
                ),
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _selectedByHid.values.toList(growable: false),
                  ),
                  child: Text('${_selectedByHid.length}명 선택 적용'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
