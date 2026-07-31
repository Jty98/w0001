import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:w0001/data/model/field_knowledge_models.dart';
import 'package:w0001/theme/app_colors.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:w0001/ui/widget/app_text_field.dart';
import 'package:w0001/ui/screen/extras/widgets/term_dictionary_card.dart';
import 'package:w0001/util/korean_chosung.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 용어사전 sticky 헤더(검색 + 초성) 높이.
double termDictionaryStickyHeaderHeight(BuildContext context) {
  return context.rs(52) + // search
      context.rsi(10) +
      context.rs(40) + // chosung
      context.rsi(16);
}

/// 스크롤 시 AppBar 아래에 고정되는 검색·초성 영역.
class TermDictionaryStickyHeader extends StatelessWidget {
  const TermDictionaryStickyHeader({
    super.key,
    required this.searchQuery,
    required this.selectedInitial,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onSelectInitial,
    this.searchController,
  });

  final String searchQuery;
  final String? selectedInitial;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;
  final ValueChanged<String?> onSelectInitial;
  final TextEditingController? searchController;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 0.5,
      shadowColor: Colors.black26,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(16),
          context.rsi(4),
          context.rsi(16),
          context.rsi(8),
        ),
        child: Column(
          children: [
            AppTextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: '검색 · 초성 (예: ㄱㅅ)',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '검색 초기화',
                        onPressed: onClearSearch,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
            ),
            SizedBox(height: context.rsi(10)),
            TermDictionaryChosungBar(
              selected: selectedInitial,
              onSelect: onSelectInitial,
            ),
          ],
        ),
      ),
    );
  }
}

class TermDictionaryStickyHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  TermDictionaryStickyHeaderDelegate({
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant TermDictionaryStickyHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}

/// 초성 칩 — 사전 인덱스처럼 항상 전체 초성 노출.
class TermDictionaryChosungBar extends StatelessWidget {
  const TermDictionaryChosungBar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      height: context.rs(40),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kKoreanInitialIndex.length + 1,
        separatorBuilder: (_, __) => SizedBox(width: context.rsi(6)),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = selected == null;
            return _IndexChip(
              label: '전체',
              selected: isSelected,
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(null);
              },
              selectedColor: cs.primary,
              labelStyle: tt.labelMedium,
            );
          }

          final key = kKoreanInitialIndex[index - 1];
          final isSelected = selected == key;
          return _IndexChip(
            label: key,
            selected: isSelected,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(isSelected ? null : key);
            },
            selectedColor: cs.primary,
            labelStyle: tt.labelLarge,
          );
        },
      ),
    );
  }
}

List<KnowledgeEntry> filterTermDictionaryItems({
  required List<KnowledgeEntry> items,
  required String searchQuery,
}) {
  final q = searchQuery.trim();
  if (q.isEmpty) return items;

  // 초성만 입력한 경우(예: ㄱㅅ) — 서버 initial 은 단일 초성이라 로컬 매칭
  if (!isChosungOnlyQuery(q)) return items;

  return items
      .where(
        (e) => matchesDictionaryQuery(
          title: e.title,
          query: q,
          standardName: e.termExtras?.standardName,
          aliases: e.termExtras?.aliases ?? const [],
        ),
      )
      .toList();
}

/// 용어 목록 sliver 본문.
List<Widget> buildTermDictionarySlivers({
  required BuildContext context,
  required List<KnowledgeEntry> filtered,
  required int total,
  required bool isLoading,
  required bool isLoadingMore,
  required bool hasNext,
  required String searchQuery,
  required String? selectedInitial,
  required void Function(KnowledgeEntry) onTap,
  void Function(KnowledgeEntry)? onEdit,
}) {
  final padH = context.rsi(16);
  final bottom = MediaQuery.paddingOf(context).bottom + context.rsi(32);

  if (isLoading && filtered.isEmpty) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: const AppLoadingIndicator(label: '용어 불러오는 중...'),
      ),
    ];
  }

  if (filtered.isEmpty) {
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(padH, context.rsi(32), padH, bottom),
        sliver: SliverToBoxAdapter(
          child: Column(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: context.rsi(40),
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              SizedBox(height: context.rsi(10)),
              Text(
                searchQuery.isNotEmpty || selectedInitial != null
                    ? (hasNext ? '일치하는 용어를 찾는 중…' : '일치하는 용어가 없습니다.')
                    : '등록된 용어가 없습니다.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              if (isLoadingMore) ...[
                SizedBox(height: context.rsi(16)),
                const AppLoadingIndicator(size: 48),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  final sections = groupWorkersByInitial(filtered, (e) => e.title);
  final sectionKeys = orderedInitialSectionKeys(sections);
  final children = <Widget>[
    Padding(
      padding: EdgeInsets.fromLTRB(padH, context.rsi(8), padH, context.rsi(4)),
      child: Text(
        selectedInitial == null
            ? '전체 $total어'
            : '$selectedInitial · ${filtered.length}어',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
      ),
    ),
  ];

  for (final key in sectionKeys) {
    children.add(
      Padding(
        padding:
            EdgeInsets.fromLTRB(padH, context.rsi(10), padH, context.rsi(8)),
        child: _SectionHeader(label: key),
      ),
    );
    for (final entry in sections[key]!) {
      children.add(
        Padding(
          padding: EdgeInsets.fromLTRB(padH, 0, padH, context.rsi(10)),
          child: TermDictionaryCard(
            entry: entry,
            onTap: () => onTap(entry),
            onEdit: onEdit != null ? () => onEdit(entry) : null,
          ),
        ),
      );
    }
  }

  if (isLoadingMore) {
    children.add(
      Padding(
        padding: EdgeInsets.symmetric(vertical: context.rsi(16)),
        child: const AppLoadingIndicator(size: 52),
      ),
    );
  } else {
    children.add(SizedBox(height: bottom));
  }

  return [
    SliverList(delegate: SliverChildListDelegate(children)),
  ];
}

class _IndexChip extends StatelessWidget {
  const _IndexChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
    required this.labelStyle,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: BoxConstraints(minWidth: context.rsi(36)),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: context.rsi(12)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? selectedColor : AppColors.borderColor,
            ),
          ),
          child: Text(
            label,
            style: labelStyle?.copyWith(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: context.rsi(28),
          height: context.rsi(28),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.primary,
            ),
          ),
        ),
        SizedBox(width: context.rsi(10)),
        const Expanded(
          child: Divider(color: AppColors.borderColor, height: 1),
        ),
      ],
    );
  }
}
