import 'package:flutter/material.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/theme/app_segmented_button.dart';
import 'package:w0001/ui/widget/worker_grouped_list/worker_grouped_list_utils.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/ui/widget/worker_grouped_list/worker_grouped_person_tile.dart';
import 'package:w0001/util/worker_skills_display.dart';

import 'package:w0001/ui/widget/worker_grouped_list/worker_grouped_list_layout.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 초성·역할별로 묶어 보여 주는 인력 목록 바텀시트.
Future<void> showWorkerGroupedListSheet({
  required BuildContext context,
  required String title,
  required List<HumanModel> workers,
  required void Function(HumanModel human) onWorkerTap,
  Widget Function(BuildContext context, HumanModel human)? personTileBuilder,
  double initialChildSize = 0.78,
}) async {
  if (workers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('표시할 인력이 없습니다.')),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: initialChildSize,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) {
          return WorkerGroupedListSheetBody(
            title: title,
            workers: workers,
            scrollController: scrollController,
            onWorkerTap: (h) {
              Navigator.of(sheetCtx).pop();
              onWorkerTap(h);
            },
            personTileBuilder: personTileBuilder,
          );
        },
      );
    },
  );
}

class WorkerGroupedListSheetBody extends StatefulWidget {
  const WorkerGroupedListSheetBody({
    super.key,
    required this.title,
    required this.workers,
    required this.scrollController,
    required this.onWorkerTap,
    this.personTileBuilder,
  });

  final String title;
  final List<HumanModel> workers;
  final ScrollController scrollController;
  final void Function(HumanModel human) onWorkerTap;
  final Widget Function(BuildContext context, HumanModel human)?
      personTileBuilder;

  @override
  State<WorkerGroupedListSheetBody> createState() =>
      _WorkerGroupedListSheetBodyState();
}

class _WorkerGroupedListSheetBodyState
    extends State<WorkerGroupedListSheetBody> {
  int _groupMode = 0;
  String? _highlightSectionKey;

  Map<String, List<HumanModel>> _buildSections() {
    if (_groupMode == 1) {
      return groupWorkersByRole(
        widget.workers,
        (h) => h.effectiveDefaultWorkRole,
      );
    }
    return groupWorkersByInitial(widget.workers, (h) => h.hname);
  }

  List<String> _orderedKeys(Map<String, List<HumanModel>> sections) {
    if (_groupMode == 1) {
      return orderedRoleSectionKeys(sections);
    }
    return orderedInitialSectionKeys(sections);
  }

  List<String> _initialChipKeys(Map<String, List<HumanModel>> sections) {
    final extras = sections.keys
        .where((k) => !kKoreanInitialIndex.contains(k))
        .toList()
      ..sort();
    return [...kKoreanInitialIndex, ...extras];
  }

  double _scrollOffsetForSection(
    String targetKey,
    Map<String, List<HumanModel>> sections,
    List<String> orderedKeys,
  ) {
    var offset = 0.0;
    for (final k in orderedKeys) {
      if (k == targetKey) break;
      final count = sections[k]?.length ?? 0;
      offset += kWorkerGroupedSectionHeaderExtent +
          count * kWorkerGroupedPersonTileExtent;
    }
    return offset;
  }

  void _jumpTo(String key) {
    final sections = _buildSections();
    if (!sections.containsKey(key)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「$key」에 해당하는 인력이 없습니다.'),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() => _highlightSectionKey = key);

    final orderedKeys = _orderedKeys(sections);
    final targetOffset = _scrollOffsetForSection(key, sections, orderedKeys);

    void animateScroll() {
      if (!widget.scrollController.hasClients) return;
      final max = widget.scrollController.position.maxScrollExtent;
      widget.scrollController.animateTo(
        targetOffset.clamp(0.0, max),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }

    if (widget.scrollController.hasClients) {
      animateScroll();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        animateScroll();
      });
    }
  }

  Widget _sectionHeader(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final highlighted = _highlightSectionKey == label;
    return Container(
      margin: EdgeInsets.only(
        top: context.rsi(14),
        bottom: context.rsi(6),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(12),
        vertical: context.rsi(8),
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? cs.primaryContainer.withValues(alpha: 0.45)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.rsi(10)),
        border: Border.all(
          color: highlighted
              ? cs.primary
              : cs.outlineVariant.withValues(alpha: 0.75),
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: tt.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: highlighted ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _defaultPersonTile(BuildContext context, HumanModel h) {
    final cs = Theme.of(context).colorScheme;
    final role = h.hdefaultRole.trim();
    return WorkerGroupedPersonTile(
      name: h.hname,
      subtitle: formatWorkerGroupedPersonSubtitle(
        wageLabel: '일당 ${getPrice(price: h.hdailyWage)}',
        role: role,
      ),
      onTap: () => widget.onWorkerTap(h),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: cs.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sections = _buildSections();
    final orderedKeys = _orderedKeys(sections);
    final chipKeys = _groupMode == 0 ? _initialChipKeys(sections) : orderedKeys;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(16),
              context.rsi(6),
              context.rsi(16),
              context.rsi(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: AppSegmentedButton.styleFrom(),
                  segments: const [
                    ButtonSegment(value: 0, label: Text('초성')),
                    ButtonSegment(value: 1, label: Text('역할')),
                  ],
                  selected: {_groupMode},
                  onSelectionChanged: (s) {
                    setState(() {
                      _groupMode = s.first;
                      _highlightSectionKey = null;
                    });
                  },
                ),
              ],
            ),
          ),
          SizedBox(
            height: context.rs(42),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: context.rsi(12)),
              scrollDirection: Axis.horizontal,
              itemCount: chipKeys.length,
              separatorBuilder: (_, __) => SizedBox(width: context.rsi(8)),
              itemBuilder: (_, i) {
                final k = chipKeys[i];
                final hasSection = sections.containsKey(k);
                final selected = _highlightSectionKey == k;
                return ActionChip(
                  label: Text(k),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: selected
                      ? cs.primaryContainer
                      : hasSection
                          ? cs.secondaryContainer.withValues(alpha: 0.65)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  side: selected
                      ? BorderSide(color: cs.primary, width: 1.2)
                      : null,
                  labelStyle: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? cs.primary
                        : hasSection
                            ? cs.onSecondaryContainer
                            : cs.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                  onPressed: hasSection ? () => _jumpTo(k) : null,
                );
              },
            ),
          ),
          SizedBox(height: context.rsi(8)),
          Expanded(
            child: CustomScrollView(
              controller: widget.scrollController,
              slivers: [
                for (final key in orderedKeys) ...[
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: context.rsi(16)),
                    sliver: SliverToBoxAdapter(
                      child: _sectionHeader(context, key),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: context.rsi(16)),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final h = sections[key]![index];
                          return widget.personTileBuilder?.call(context, h) ??
                              _defaultPersonTile(context, h);
                        },
                        childCount: sections[key]?.length ?? 0,
                      ),
                    ),
                  ),
                ],
                SliverPadding(
                  padding: EdgeInsets.only(bottom: context.rsi(16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
