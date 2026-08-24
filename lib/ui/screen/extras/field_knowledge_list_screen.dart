import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/data/model/field_knowledge_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/field_knowledge_providers.dart';
import 'package:w0001/ui/screen/extras/field_knowledge_construction_case_detail_screen.dart';
import 'package:w0001/ui/screen/extras/field_knowledge_detail_screen.dart';
import 'package:w0001/ui/screen/extras/field_knowledge_editor_screen.dart';
import 'package:w0001/ui/screen/extras/hardware_dictionary_style.dart';
import 'package:w0001/ui/screen/extras/widgets/term_dictionary_list_body.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/app_text_field.dart';
import 'package:w0001/util/korean_chosung.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 현장 지식 항목 리스트 — 철물 사전, 용어사전, 베스트/워스트 시공사례
class FieldKnowledgeListScreen extends ConsumerStatefulWidget {
  const FieldKnowledgeListScreen({
    super.key,
    required this.type,
    this.hardwareKind,
  });

  final KnowledgeEntryType type;
  final HardwareDictionaryKind? hardwareKind;

  @override
  ConsumerState<FieldKnowledgeListScreen> createState() =>
      _FieldKnowledgeListScreenState();
}

class _FieldKnowledgeListScreenState
    extends ConsumerState<FieldKnowledgeListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedSubcategory;

  bool get _isTermDictionary => widget.type == KnowledgeEntryType.term;
  bool get _isHardwareDictionary =>
      widget.type == KnowledgeEntryType.material && widget.hardwareKind != null;

  String get _screenTitle {
    final kind = widget.hardwareKind;
    if (kind != null) return kind.label;
    return widget.type.displayName;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fieldKnowledgeListProvider.notifier).load(
            filter: KnowledgeFilter(
              type: widget.type,
              categories: widget.hardwareKind == null
                  ? const <String>[]
                  : KnowledgeCategories.filterCategoriesFor(
                      kind: widget.hardwareKind!,
                    ),
              sortBy: _isTermDictionary
                  ? KnowledgeSortBy.title
                  : KnowledgeSortBy.recent,
            ),
          );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(fieldKnowledgeListProvider.notifier).loadMore();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
    ref.read(fieldKnowledgeListProvider.notifier).search('');
  }

  void _submitSearch(String value) {
    setState(() => _searchQuery = value);
    if (_isTermDictionary && isChosungOnlyQuery(value)) {
      final compact = value.replaceAll(' ', '');
      // 단일 초성 → 서버 initial (칩과 동일)
      if (compact.length == 1 &&
          kKoreanInitialIndex
              .contains(normalizeKoreanInitialChipKey(compact))) {
        _searchController.clear();
        setState(() => _searchQuery = '');
        ref.read(fieldKnowledgeListProvider.notifier).setInitial(
              normalizeKoreanInitialChipKey(compact),
            );
        return;
      }
      // 복합 초성(ㄱㅅ 등)은 로컬 필터
      final currentQuery = ref.read(fieldKnowledgeListProvider).filter.query;
      if (currentQuery.isNotEmpty) {
        ref.read(fieldKnowledgeListProvider.notifier).search('');
      }
      return;
    }
    ref.read(fieldKnowledgeListProvider.notifier).search(value);
  }

  void _selectSubcategory(String? subcategory) {
    final kind = widget.hardwareKind;
    if (kind == null) return;
    setState(() => _selectedSubcategory = subcategory);
    final current = ref.read(fieldKnowledgeListProvider).filter;
    ref.read(fieldKnowledgeListProvider.notifier).setFilter(
          current.copyWith(
            categories: KnowledgeCategories.filterCategoriesFor(
              kind: kind,
              subcategory: subcategory,
            ),
          ),
        );
  }

  List<KnowledgeEntry> _visibleItems(List<KnowledgeEntry> items) {
    final kind = widget.hardwareKind;
    if (kind == null) return items;
    if (kind == HardwareDictionaryKind.material &&
        (_selectedSubcategory == null || _selectedSubcategory!.isEmpty)) {
      return items
          .where(
            (entry) =>
                KnowledgeCategories.hardwareKindOf(entry.categories) ==
                HardwareDictionaryKind.material,
          )
          .toList(growable: false);
    }
    return items;
  }

  /// 복합 초성 검색 결과가 비었고 다음 페이지가 있으면 이어서 로드.
  void _maybeLoadMoreForLocalChosungSearch(FieldKnowledgeListState state) {
    if (!_isTermDictionary) return;
    if (!isChosungOnlyQuery(_searchQuery)) return;
    final filtered = filterTermDictionaryItems(
      items: state.items,
      searchQuery: _searchQuery,
    );
    if (filtered.isEmpty && state.hasNext && !state.isLoadingMore) {
      ref.read(fieldKnowledgeListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider).asData?.value;
    final canManage = user?.role.canManageExtras ?? false;
    final state = ref.watch(fieldKnowledgeListProvider);
    final cs = Theme.of(context).colorScheme;

    ref.listen(fieldKnowledgeListProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
      _maybeLoadMoreForLocalChosungSearch(next);
    });

    if (_isTermDictionary) {
      return _buildTermDictionaryScaffold(
        context: context,
        state: state,
        canManage: canManage,
      );
    }

    final visibleItems = _visibleItems(state.items);
    final displayTotal =
        widget.hardwareKind == HardwareDictionaryKind.material &&
                (_selectedSubcategory == null || _selectedSubcategory!.isEmpty)
            ? visibleItems.length
            : state.total;

    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: state.isSaving
                  ? null
                  : () => _openEditor(context, type: widget.type),
              icon: const Icon(Icons.add_rounded),
              label: const Text('추가'),
            )
          : null,
      body: AppRefreshIndicator(
        enabled: !(state.isLoading && state.items.isEmpty),
        onRefresh: () => ref.read(fieldKnowledgeListProvider.notifier).load(),
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            context.rsi(16),
            context.rsi(12),
            context.rsi(16),
            MediaQuery.paddingOf(context).bottom +
                (canManage ? context.rsi(96) : context.rsi(32)),
          ),
          children: [
            AppTextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: _isHardwareDictionary ? '이름이나 카테고리로 검색' : '검색',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '검색 초기화',
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
              onSubmitted: _submitSearch,
            ),
            if (_isHardwareDictionary) ...[
              SizedBox(height: context.rsi(12)),
              _HardwareSubcategoryChips(
                kind: widget.hardwareKind!,
                selected: _selectedSubcategory,
                onSelected: _selectSubcategory,
              ),
            ],
            SizedBox(height: context.rsi(16)),
            _StatsBanner(
              type: widget.type,
              title: _screenTitle,
              total: displayTotal,
              isLoading: state.isLoading,
              hardwareKind: widget.hardwareKind,
            ),
            SizedBox(height: context.rsi(16)),
            if (state.isLoading && state.items.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: context.rsi(48)),
                child: const AppLoadingIndicator(),
              )
            else if (visibleItems.isEmpty)
              _EmptyState(
                type: widget.type,
                title: _screenTitle,
                onAdd: canManage
                    ? () => _openEditor(context, type: widget.type)
                    : null,
              )
            else if (widget.type.hasImages)
              _GridView(
                items: visibleItems,
                hardwareKind: widget.hardwareKind,
                onTap: (entry) => _openDetail(context, entry),
                onEdit: canManage
                    ? (entry) => _openEditor(context, existing: entry)
                    : null,
              )
            else
              _ListView(
                items: visibleItems,
                onTap: (entry) => _openDetail(context, entry),
                onEdit: canManage
                    ? (entry) => _openEditor(context, existing: entry)
                    : null,
              ),
            if (state.isLoadingMore)
              Padding(
                padding: EdgeInsets.symmetric(vertical: context.rsi(16)),
                child: Center(
                  child: const HammerLoadingIndicator(size: 28),
                ),
              ),
            if (state.isSaving)
              Padding(
                padding: EdgeInsets.only(top: context.rsi(8)),
                child: LinearProgressIndicator(color: cs.primary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermDictionaryScaffold({
    required BuildContext context,
    required FieldKnowledgeListState state,
    required bool canManage,
  }) {
    final selectedInitial = state.filter.initial;
    final filtered = filterTermDictionaryItems(
      items: state.items,
      searchQuery: _searchQuery,
    );
    final stickyHeight = termDictionaryStickyHeaderHeight(context);

    return Scaffold(
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: state.isSaving
                  ? null
                  : () => _openEditor(context, type: widget.type),
              icon: const Icon(Icons.add_rounded),
              label: const Text('추가'),
            )
          : null,
      body: AppRefreshIndicator(
        enabled: !(state.isLoading && state.items.isEmpty),
        onRefresh: () => ref.read(fieldKnowledgeListProvider.notifier).load(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: false,
              title: Text(widget.type.displayName),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: TermDictionaryStickyHeaderDelegate(
                height: stickyHeight,
                child: TermDictionaryStickyHeader(
                  searchQuery: _searchQuery,
                  selectedInitial: selectedInitial,
                  searchController: _searchController,
                  onSearchChanged: (value) {
                    setState(() => _searchQuery = value);
                    if (value.isEmpty || isChosungOnlyQuery(value)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _maybeLoadMoreForLocalChosungSearch(
                          ref.read(fieldKnowledgeListProvider),
                        );
                      });
                    }
                  },
                  onSearchSubmitted: _submitSearch,
                  onClearSearch: _clearSearch,
                  onSelectInitial: (value) {
                    ref
                        .read(fieldKnowledgeListProvider.notifier)
                        .setInitial(value);
                  },
                ),
              ),
            ),
            ...buildTermDictionarySlivers(
              context: context,
              filtered: filtered,
              total: state.total,
              isLoading: state.isLoading,
              isLoadingMore: state.isLoadingMore,
              hasNext: state.hasNext,
              searchQuery: _searchQuery,
              selectedInitial: selectedInitial,
              onTap: (entry) => _openDetail(context, entry),
              onEdit: canManage
                  ? (entry) => _openEditor(context, existing: entry)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, KnowledgeEntry entry) {
    if (entry.type == KnowledgeEntryType.constructionCase) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              FieldKnowledgeConstructionCaseDetailScreen(entryId: entry.id),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FieldKnowledgeDetailScreen(entryId: entry.id),
        ),
      );
    }
  }

  void _openEditor(
    BuildContext context, {
    KnowledgeEntryType? type,
    KnowledgeEntry? existing,
  }) async {
    KnowledgeEntry? resolvedExisting = existing;
    if (existing != null) {
      try {
        // 리스트 응답은 시공사례 베스트/워스트를 축약해 내려줄 수 있어,
        // 수정 진입 전 상세를 한번 조회해 초기값 유실을 막는다.
        final detailed =
            await ref.read(fieldKnowledgeEntryProvider(existing.id).future);
        if (detailed != null) {
          resolvedExisting = detailed;
        }
      } catch (_) {
        // 상세 조회 실패 시에는 리스트 데이터를 그대로 사용한다.
      }
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FieldKnowledgeEditorScreen(
          type: type ?? widget.type,
          existingEntry: resolvedExisting,
          initialHardwareKind: widget.hardwareKind,
        ),
      ),
    );

    if (result == true && mounted) {
      await ref.read(fieldKnowledgeListProvider.notifier).load();
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 철물 사전 하위 카테고리 칩
// ────────────────────────────────────────────────────────────────────────────

class _HardwareSubcategoryChips extends StatelessWidget {
  const _HardwareSubcategoryChips({
    required this.kind,
    required this.selected,
    required this.onSelected,
  });

  final HardwareDictionaryKind kind;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = HardwareDictionaryStyle.accentFor(kind);
    final categories = KnowledgeCategories.forHardwareKind(kind);

    Widget pill({
      required String label,
      required bool isSelected,
      required VoidCallback onTap,
      IconData? icon,
    }) {
      return Material(
        color: isSelected ? accent : cs.surface,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.rsi(11),
              vertical: context.rsi(8),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? accent
                    : cs.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: context.rsi(14),
                    color: isSelected ? Colors.white : accent,
                  ),
                  SizedBox(width: context.rsi(5)),
                ],
                Text(
                  label,
                  style: tt.labelMedium?.copyWith(
                    color: isSelected ? Colors.white : cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: context.rsi(8),
      runSpacing: context.rsi(8),
      children: [
        pill(
          label: '전체',
          isSelected: selected == null || selected!.isEmpty,
          onTap: () => onSelected(null),
        ),
        for (final category in categories)
          pill(
            label: category,
            isSelected: selected == category,
            icon: HardwareDictionaryStyle.iconForCategory(category),
            onTap: () => onSelected(category),
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 통계 배너
// ────────────────────────────────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  const _StatsBanner({
    required this.type,
    required this.total,
    required this.isLoading,
    this.title,
    this.hardwareKind,
  });

  final KnowledgeEntryType type;
  final String? title;
  final int total;
  final bool isLoading;
  final HardwareDictionaryKind? hardwareKind;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = hardwareKind == null
        ? cs.primary
        : HardwareDictionaryStyle.accentFor(hardwareKind!);

    return Container(
      padding: EdgeInsets.all(context.rsi(16)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.16),
            cs.surfaceContainerHighest.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(context.rsi(10)),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hardwareKind == null
                  ? _getTypeIcon(type)
                  : HardwareDictionaryStyle.iconForKind(hardwareKind!),
              color: accent,
              size: context.rsi(24),
            ),
          ),
          SizedBox(width: context.rsi(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? type.displayName,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: context.rsi(2)),
                Text(
                  isLoading ? '불러오는 중...' : '총 $total개',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(KnowledgeEntryType type) {
    switch (type) {
      case KnowledgeEntryType.material:
        return Icons.hardware_outlined;
      case KnowledgeEntryType.term:
        return Icons.menu_book_outlined;
      case KnowledgeEntryType.constructionCase:
        return Icons.compare_outlined;
      case KnowledgeEntryType.processGuide:
        return Icons.construction_outlined;
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 빈 상태
// ────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.type,
    this.title,
    this.onAdd,
  });

  final KnowledgeEntryType type;
  final String? title;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rsi(48)),
      child: Column(
        children: [
          Icon(
            _getTypeIcon(type),
            size: context.rsi(48),
            color: Theme.of(context).colorScheme.outline,
          ),
          SizedBox(height: context.rsi(12)),
          Text(
            '등록된 ${title ?? type.displayName} 항목이 없습니다.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (onAdd != null) ...[
            SizedBox(height: context.rsi(8)),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('첫 항목 추가'),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getTypeIcon(KnowledgeEntryType type) {
    switch (type) {
      case KnowledgeEntryType.material:
        return Icons.hardware_outlined;
      case KnowledgeEntryType.term:
        return Icons.menu_book_outlined;
      case KnowledgeEntryType.constructionCase:
        return Icons.compare_outlined;
      case KnowledgeEntryType.processGuide:
        return Icons.construction_outlined;
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 그리드 뷰 (철물 사전, 베스트/워스트 사례 — 이미지 포함)
// ────────────────────────────────────────────────────────────────────────────

class _GridView extends StatelessWidget {
  const _GridView({
    required this.items,
    required this.onTap,
    this.onEdit,
    this.hardwareKind,
  });

  final List<KnowledgeEntry> items;
  final void Function(KnowledgeEntry) onTap;
  final void Function(KnowledgeEntry)? onEdit;
  final HardwareDictionaryKind? hardwareKind;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 3 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 0.75,
        crossAxisSpacing: context.rsi(12),
        mainAxisSpacing: context.rsi(12),
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final entry = items[index];
        return _GridCard(
          entry: entry,
          hardwareKind: hardwareKind,
          onTap: () => onTap(entry),
          onEdit: onEdit != null ? () => onEdit!(entry) : null,
        );
      },
    );
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({
    required this.entry,
    required this.onTap,
    this.onEdit,
    this.hardwareKind,
  });

  final KnowledgeEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final HardwareDictionaryKind? hardwareKind;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hideTags = hardwareKind == HardwareDictionaryKind.tool;
    final category = KnowledgeCategories.primarySubcategory(
      entry.categories,
      kind: hardwareKind,
    );
    final accent = hardwareKind == null
        ? cs.primary
        : HardwareDictionaryStyle.accentFor(hardwareKind!);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  entry.primaryImageUrl != null
                      ? Image.network(
                          entry.primaryImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _PlaceholderImage(type: entry.type),
                        )
                      : _PlaceholderImage(type: entry.type),
                  if (category != null)
                    Positioned(
                      left: context.rsi(8),
                      bottom: context.rsi(8),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rsi(8),
                          vertical: context.rsi(4),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          category,
                          style: tt.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.rsi(12),
                context.rsi(10),
                context.rsi(8),
                context.rsi(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!hideTags && entry.tags.isNotEmpty) ...[
                    SizedBox(height: context.rsi(6)),
                    Wrap(
                      spacing: context.rsi(4),
                      children: entry.tags.take(2).map((tag) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.rsi(6),
                            vertical: context.rsi(2),
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#$tag',
                            style: tt.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (onEdit != null) ...[
                    SizedBox(height: context.rsi(4)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        iconSize: context.rsi(18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 리스트 뷰 (용어사전 — 텍스트만)
// ────────────────────────────────────────────────────────────────────────────

class _ListView extends StatelessWidget {
  const _ListView({
    required this.items,
    required this.onTap,
    this.onEdit,
  });

  final List<KnowledgeEntry> items;
  final void Function(KnowledgeEntry) onTap;
  final void Function(KnowledgeEntry)? onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((entry) {
        return Padding(
          padding: EdgeInsets.only(bottom: context.rsi(10)),
          child: _ListCard(
            entry: entry,
            onTap: () => onTap(entry),
            onEdit: onEdit != null ? () => onEdit!(entry) : null,
          ),
        );
      }).toList(),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.entry,
    required this.onTap,
    this.onEdit,
  });

  final KnowledgeEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(context.rsi(16)),
          child: Row(
            children: [
              Container(
                width: context.rsi(40),
                height: context.rsi(40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.menu_book_outlined,
                  color: cs.primary,
                  size: context.rsi(20),
                ),
              ),
              SizedBox(width: context.rsi(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style:
                          tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: context.rsi(4)),
                    Text(
                      entry.content,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.tags.isNotEmpty) ...[
                      SizedBox(height: context.rsi(6)),
                      Text(
                        entry.tags.take(3).map((t) => '#$t').join(' '),
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  iconSize: context.rsi(20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 플레이스홀더 이미지
// ────────────────────────────────────────────────────────────────────────────

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage({required this.type});

  final KnowledgeEntryType type;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _getColor(type, cs);

    return Container(
      color: color.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          _getIcon(type),
          size: context.rsi(48),
          color: color,
        ),
      ),
    );
  }

  IconData _getIcon(KnowledgeEntryType type) {
    switch (type) {
      case KnowledgeEntryType.material:
        return Icons.hardware_outlined;
      case KnowledgeEntryType.constructionCase:
        return Icons.compare_outlined;
      case KnowledgeEntryType.term:
        return Icons.menu_book_outlined;
      case KnowledgeEntryType.processGuide:
        return Icons.construction_outlined;
    }
  }

  Color _getColor(KnowledgeEntryType type, ColorScheme cs) {
    switch (type) {
      case KnowledgeEntryType.material:
        return cs.primary;
      case KnowledgeEntryType.constructionCase:
        return Colors.teal;
      case KnowledgeEntryType.term:
        return cs.secondary;
      case KnowledgeEntryType.processGuide:
        return Colors.orange;
    }
  }
}
