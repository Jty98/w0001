import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/data/model/field_knowledge_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/field_knowledge_providers.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/screen/extras/field_knowledge_editor_screen.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 시공사례 상세 화면 (베스트 ↔ 워스트 세그먼트)
class FieldKnowledgeConstructionCaseDetailScreen
    extends ConsumerStatefulWidget {
  const FieldKnowledgeConstructionCaseDetailScreen({
    super.key,
    required this.entryId,
  });

  final int entryId;

  @override
  ConsumerState<FieldKnowledgeConstructionCaseDetailScreen> createState() =>
      _FieldKnowledgeConstructionCaseDetailScreenState();
}

class _FieldKnowledgeConstructionCaseDetailScreenState
    extends ConsumerState<FieldKnowledgeConstructionCaseDetailScreen> {
  ConstructionExampleType _selectedType = ConstructionExampleType.best;

  Future<void> _openEditor(KnowledgeEntry entry) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FieldKnowledgeEditorScreen(
          type: KnowledgeEntryType.constructionCase,
          existingEntry: entry,
        ),
      ),
    );
    if (!mounted || result != true) return;
    ref.invalidate(fieldKnowledgeEntryProvider(widget.entryId));
    ref.invalidate(fieldKnowledgeRelatedEntriesProvider(widget.entryId));
    ref.read(fieldKnowledgeListProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final entryAsync = ref.watch(fieldKnowledgeEntryProvider(widget.entryId));
    final relatedAsync =
        ref.watch(fieldKnowledgeRelatedEntriesProvider(widget.entryId));
    final canManage =
        ref.watch(authSessionProvider).asData?.value?.role.canManageExtras ??
            false;
    final entry = entryAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('시공사례'),
        actions: [
          if (canManage &&
              entry != null &&
              entry.type == KnowledgeEntryType.constructionCase)
            IconButton(
              tooltip: '수정',
              onPressed: () => _openEditor(entry),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: AppRefreshIndicator(
        enabled: !(entryAsync.isLoading && !entryAsync.hasValue),
        onRefresh: () async {
          ref.invalidate(fieldKnowledgeEntryProvider(widget.entryId));
          ref.invalidate(fieldKnowledgeRelatedEntriesProvider(widget.entryId));
          await ref.read(fieldKnowledgeEntryProvider(widget.entryId).future);
        },
        child: entryAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 240),
              const AppLoadingIndicator(),
            ],
          ),
          error: (error, stack) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(context.rsi(24)),
            children: [
              SizedBox(height: context.rsi(80)),
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: context.rsi(16)),
              Text(
                '데이터를 불러오지 못했습니다.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.rsi(8)),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          data: (entry) {
            if (entry == null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 240),
                  Center(child: Text('항목을 찾을 수 없습니다.')),
                ],
              );
            }
            if (entry.type != KnowledgeEntryType.constructionCase) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 240),
                  Center(child: Text('시공사례 항목이 아닙니다.')),
                ],
              );
            }
            return _DetailBody(
              entry: entry,
              selectedType: _selectedType,
              onTypeChanged: (type) => setState(() => _selectedType = type),
              relatedEntries: relatedAsync.asData?.value ?? const [],
              canManage: canManage,
              onEdit: () => _openEditor(entry),
            );
          },
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.entry,
    required this.selectedType,
    required this.onTypeChanged,
    required this.relatedEntries,
    required this.canManage,
    required this.onEdit,
  });

  final KnowledgeEntry entry;
  final ConstructionExampleType selectedType;
  final ValueChanged<ConstructionExampleType> onTypeChanged;
  final List<KnowledgeEntry> relatedEntries;
  final bool canManage;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final examples = entry.constructionExamples;
    final bestExamples = examples?.bestExamples ?? [];
    final worstExamples = examples?.worstExamples ?? [];

    // 서버에서 포함된 연관 항목이 있으면 사용, 없으면 별도 조회 결과 사용
    final actualRelatedEntries =
        entry.hasRelatedEntries ? entry.relatedEntries : relatedEntries;

    final isEmptySelected = (selectedType == ConstructionExampleType.best &&
            bestExamples.isEmpty) ||
        (selectedType == ConstructionExampleType.worst &&
            worstExamples.isEmpty);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        context.rsi(16),
        context.rsi(12),
        context.rsi(16),
        MediaQuery.paddingOf(context).bottom + context.rsi(32),
      ),
      children: [
        // 헤더 (타입 배지 + 제목)
        _DetailHeader(entry: entry),
        SizedBox(height: context.rsi(16)),

        // 본문 내용
        AppInsetCard(
          padding: EdgeInsets.all(context.rsi(16)),
          child: Text(
            entry.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
          ),
        ),
        SizedBox(height: context.rsi(16)),

        // 세그먼트 버튼 (베스트 ↔ 워스트)
        _SegmentedSelector(
          selectedType: selectedType,
          onTypeChanged: onTypeChanged,
          bestCount: bestExamples.length,
          worstCount: worstExamples.length,
        ),
        SizedBox(height: context.rsi(16)),

        // 예시들
        if (selectedType == ConstructionExampleType.best)
          ...bestExamples.map((example) => _ExampleCard(
                example: example,
                type: ConstructionExampleType.best,
              ))
        else
          ...worstExamples.map((example) => _ExampleCard(
                example: example,
                type: ConstructionExampleType.worst,
              )),

        // 빈 상태
        if (isEmptySelected)
          _EmptyExamples(
            type: selectedType,
            onEdit: canManage ? onEdit : null,
          ),

        SizedBox(height: context.rsi(16)),

        // 태그
        if (entry.tags.isNotEmpty) ...[
          _TagSection(tags: entry.tags),
          SizedBox(height: context.rsi(16)),
        ],

        // 연관 항목
        if (actualRelatedEntries.isNotEmpty) ...[
          _RelatedSection(entries: actualRelatedEntries),
          SizedBox(height: context.rsi(16)),
        ],

        // 메타 정보
        _MetaSection(entry: entry),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 헤더
// ────────────────────────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.entry});

  final KnowledgeEntry entry;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(12),
            vertical: context.rsi(6),
          ),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.compare_outlined,
                size: context.rsi(16),
                color: Colors.teal,
              ),
              SizedBox(width: context.rsi(6)),
              Text(
                '시공사례',
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.rsi(12)),
        Text(
          entry.title,
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 세그먼트 선택기
// ────────────────────────────────────────────────────────────────────────────

class _SegmentedSelector extends StatelessWidget {
  const _SegmentedSelector({
    required this.selectedType,
    required this.onTypeChanged,
    required this.bestCount,
    required this.worstCount,
  });

  final ConstructionExampleType selectedType;
  final ValueChanged<ConstructionExampleType> onTypeChanged;
  final int bestCount;
  final int worstCount;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ConstructionExampleType>(
      segments: [
        ButtonSegment(
          value: ConstructionExampleType.best,
          icon: const Icon(Icons.workspace_premium_outlined),
          label: Text('베스트 ($bestCount)'),
        ),
        ButtonSegment(
          value: ConstructionExampleType.worst,
          icon: const Icon(Icons.warning_amber_rounded),
          label: Text('워스트 ($worstCount)'),
        ),
      ],
      selected: {selectedType},
      onSelectionChanged: (selection) => onTypeChanged(selection.first),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 예시 카드
// ────────────────────────────────────────────────────────────────────────────

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.example,
    required this.type,
  });

  final ConstructionExample example;
  final ConstructionExampleType type;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accentColor =
        type == ConstructionExampleType.best ? Colors.teal : cs.error;

    return Padding(
      padding: EdgeInsets.only(bottom: context.rsi(12)),
      child: AppInsetCard(
        padding: EdgeInsets.all(context.rsi(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (example.imageUrls.isNotEmpty) ...[
              _ExampleImageGallery(imageUrls: example.imageUrls),
              SizedBox(height: context.rsi(12)),
            ],

            // 설명
            Container(
              padding: EdgeInsets.all(context.rsi(12)),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    type == ConstructionExampleType.best
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: accentColor,
                    size: context.rsi(20),
                  ),
                  SizedBox(width: context.rsi(8)),
                  Expanded(
                    child: Text(
                      example.description,
                      style: tt.bodyMedium?.copyWith(
                        height: 1.5,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 팁들
            if (example.tips.isNotEmpty) ...[
              SizedBox(height: context.rsi(12)),
              ...example.tips.map((tip) {
                return Padding(
                  padding: EdgeInsets.only(bottom: context.rsi(6)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: context.rsi(4)),
                        child: Icon(
                          Icons.lightbulb_outline,
                          size: context.rsi(16),
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(width: context.rsi(8)),
                      Expanded(
                        child: Text(
                          tip,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

/// 시공 예시 이미지 — 카드 너비를 가득 채움 (세로 사진도 cover).
class _ExampleImageGallery extends StatefulWidget {
  const _ExampleImageGallery({required this.imageUrls});

  final List<String> imageUrls;

  @override
  State<_ExampleImageGallery> createState() => _ExampleImageGalleryState();
}

class _ExampleImageGalleryState extends State<_ExampleImageGallery> {
  var _page = 0;

  Future<void> _openImageViewer(int initialIndex) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenImageViewer(
          imageUrls: widget.imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final urls = widget.imageUrls;
    final radius = BorderRadius.circular(12);

    Widget imageAt(int index) {
      return GestureDetector(
        onTap: () => _openImageViewer(index),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                urls[index],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: cs.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: context.rsi(48),
                      color: cs.outline,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: context.rsi(10),
                bottom: context.rsi(10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rsi(10),
                      vertical: context.rsi(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.zoom_in_rounded,
                          size: context.rsi(14),
                          color: Colors.white,
                        ),
                        SizedBox(width: context.rsi(4)),
                        Text(
                          '확대',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          // 카드 가로를 기준으로 충분한 영역 확보 (세로 원본은 cover로 채움)
          aspectRatio: 4 / 5,
          child: urls.length == 1
              ? imageAt(0)
              : PageView.builder(
                  itemCount: urls.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, index) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.rsi(2)),
                    child: imageAt(index),
                  ),
                ),
        ),
        if (urls.length > 1) ...[
          SizedBox(height: context.rsi(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(urls.length, (i) {
              final selected = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: context.rsi(3)),
                width: selected ? context.rsi(16) : context.rsi(6),
                height: context.rsi(6),
                decoration: BoxDecoration(
                  color: selected
                      ? cs.primary
                      : cs.outlineVariant.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  const _FullscreenImageViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _controller = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_current + 1} / ${urls.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: urls.length,
        onPageChanged: (index) => setState(() => _current = index),
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.network(
                urls[index],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.broken_image_outlined,
                  color: cs.outlineVariant,
                  size: context.rsi(56),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 빈 상태
// ────────────────────────────────────────────────────────────────────────────

class _EmptyExamples extends StatelessWidget {
  const _EmptyExamples({
    required this.type,
    this.onEdit,
  });

  final ConstructionExampleType type;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rsi(48)),
      child: Column(
        children: [
          Icon(
            type == ConstructionExampleType.best
                ? Icons.workspace_premium_outlined
                : Icons.warning_amber_rounded,
            size: context.rsi(48),
            color: cs.outline,
          ),
          SizedBox(height: context.rsi(12)),
          Text(
            '등록된 ${type.displayName} 예시가 없습니다.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (onEdit != null) ...[
            SizedBox(height: context.rsi(12)),
            FilledButton.tonalIcon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('수정해서 추가'),
            ),
          ],
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 태그 섹션
// ────────────────────────────────────────────────────────────────────────────

class _TagSection extends StatelessWidget {
  const _TagSection({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppInsetCard(
      padding: EdgeInsets.all(context.rsi(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_outlined,
                  size: context.rsi(18), color: cs.primary),
              SizedBox(width: context.rsi(8)),
              Text(
                '태그',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          SizedBox(height: context.rsi(10)),
          Wrap(
            spacing: context.rsi(8),
            runSpacing: context.rsi(8),
            children: tags.map((tag) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rsi(12),
                  vertical: context.rsi(6),
                ),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$tag',
                  style: tt.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onTertiaryContainer,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 연관 항목 섹션
// ────────────────────────────────────────────────────────────────────────────

class _RelatedSection extends StatelessWidget {
  const _RelatedSection({required this.entries});

  final List<KnowledgeEntry> entries;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              EdgeInsets.only(left: context.rsi(4), bottom: context.rsi(8)),
          child: Row(
            children: [
              Icon(Icons.link_rounded,
                  size: context.rsi(18), color: cs.primary),
              SizedBox(width: context.rsi(8)),
              Text(
                '관련 자료',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        ...entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(bottom: context.rsi(8)),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.article_outlined, color: cs.primary),
                title: Text(entry.title),
                subtitle: Text(entry.type.displayName),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  // 연관 항목 클릭 - 해당 상세로 이동
                },
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 메타 정보
// ────────────────────────────────────────────────────────────────────────────

class _MetaSection extends StatelessWidget {
  const _MetaSection({required this.entry});

  final KnowledgeEntry entry;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return AppInsetCard(
      padding: EdgeInsets.all(context.rsi(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '정보',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: context.rsi(10)),
          _MetaRow(
            icon: Icons.visibility_outlined,
            label: '조회수',
            value: '${entry.viewCount}회',
          ),
          if (entry.createdAt != null) ...[
            SizedBox(height: context.rsi(8)),
            _MetaRow(
              icon: Icons.calendar_today_outlined,
              label: '등록일',
              value: _formatDate(entry.createdAt!),
            ),
          ],
          if (entry.updatedAt != null) ...[
            SizedBox(height: context.rsi(8)),
            _MetaRow(
              icon: Icons.update_outlined,
              label: '수정일',
              value: _formatDate(entry.updatedAt!),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: context.rsi(16), color: cs.onSurfaceVariant),
        SizedBox(width: context.rsi(8)),
        Text(
          label,
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
