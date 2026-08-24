import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/field_knowledge_models.dart';
import 'package:w0001/presentation/viewmodel/field_knowledge_providers.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_blocks_display.dart';
import 'package:w0001/ui/screen/extras/widgets/term_dictionary_detail_view.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 현장 지식 항목 상세 화면
class FieldKnowledgeDetailScreen extends ConsumerWidget {
  const FieldKnowledgeDetailScreen({
    super.key,
    required this.entryId,
  });

  final int entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(fieldKnowledgeEntryProvider(entryId));
    final entryType = entryAsync.asData?.value?.type;
    final relatedAsync = entryType == KnowledgeEntryType.term
        ? const AsyncValue<List<KnowledgeEntry>>.data([])
        : ref.watch(fieldKnowledgeRelatedEntriesProvider(entryId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          entryType == KnowledgeEntryType.term ? '용어' : '상세',
        ),
      ),
      body: AppRefreshIndicator(
        enabled: !(entryAsync.isLoading && !entryAsync.hasValue),
        onRefresh: () async {
          ref.invalidate(fieldKnowledgeEntryProvider(entryId));
          if (entryType != KnowledgeEntryType.term) {
            ref.invalidate(fieldKnowledgeRelatedEntriesProvider(entryId));
          }
          await ref.read(fieldKnowledgeEntryProvider(entryId).future);
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
            if (entry.type == KnowledgeEntryType.term) {
              return TermDictionaryDetailView(entry: entry);
            }
            return _DetailBody(
              entry: entry,
              relatedEntries: relatedAsync.asData?.value ?? const [],
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
    required this.relatedEntries,
  });

  final KnowledgeEntry entry;
  final List<KnowledgeEntry> relatedEntries;

  @override
  Widget build(BuildContext context) {
    // 서버에서 포함된 연관 항목이 있으면 사용, 없으면 별도 조회 결과 사용
    final actualRelatedEntries =
        entry.hasRelatedEntries ? entry.relatedEntries : relatedEntries;
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
        SizedBox(height: context.rsi(24)),

        // 이미지 갤러리 (철물 사전, 베스트/워스트 사례)
        if (entry.type.hasImages && entry.imageUrls.isNotEmpty) ...[
          AppSectionCard(
            title: '이미지',
            icon: Icons.photo_library_outlined,
            child: _ImageGallery(imageUrls: entry.imageUrls),
          ),
          SizedBox(height: context.rsi(20)),
        ],

        // 본문 내용 (Plain Text or Quill)
        if (entry.isQuillContent) ...[
          // Quill 콘텐츠 (공정 가이드)
          AppSectionCard(
            title: '작업 가이드',
            icon: Icons.construction_outlined,
            child: WorkerAnnouncementBlocksDisplay(blocks: entry.contentBlocks),
          ),
          SizedBox(height: context.rsi(20)),
        ] else ...[
          // Plain Text 콘텐츠
          AppSectionCard(
            title: '상세 내용',
            icon: Icons.article_outlined,
            child: Padding(
              padding: EdgeInsets.all(context.rsi(16)),
              child: Text(
                entry.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                    ),
              ),
            ),
          ),
          SizedBox(height: context.rsi(20)),
        ],

        // 태그
        if (entry.tags.isNotEmpty &&
            !(entry.type == KnowledgeEntryType.material &&
                KnowledgeCategories.hardwareKindOf(entry.categories) ==
                    HardwareDictionaryKind.tool)) ...[
          _TagSection(tags: entry.tags),
          SizedBox(height: context.rsi(20)),
        ],

        // 연관 항목
        if (actualRelatedEntries.isNotEmpty) ...[
          _RelatedSection(entries: actualRelatedEntries),
          SizedBox(height: context.rsi(20)),
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
    final cs = Theme.of(context).colorScheme;
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
            color: _getTypeColor(entry.type, cs).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getTypeIcon(entry.type),
                size: context.rsi(16),
                color: _getTypeColor(entry.type, cs),
              ),
              SizedBox(width: context.rsi(6)),
              Text(
                KnowledgeCategories.entryKindLabel(entry),
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _getTypeColor(entry.type, cs),
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
        if (entry.type == KnowledgeEntryType.material &&
            KnowledgeCategories.primarySubcategory(entry.categories) !=
                null) ...[
          SizedBox(height: context.rsi(10)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.rsi(10),
              vertical: context.rsi(5),
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              KnowledgeCategories.primarySubcategory(entry.categories)!,
              style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
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

  Color _getTypeColor(KnowledgeEntryType type, ColorScheme cs) {
    switch (type) {
      case KnowledgeEntryType.material:
        return cs.primary;
      case KnowledgeEntryType.term:
        return cs.secondary;
      case KnowledgeEntryType.constructionCase:
        return Colors.teal;
      case KnowledgeEntryType.processGuide:
        return Colors.orange;
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 이미지 갤러리
// ────────────────────────────────────────────────────────────────────────────

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            imageUrls.first,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _ErrorPlaceholder(),
          ),
        ),
      );
    }

    return SizedBox(
      height: context.rsi(220),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        separatorBuilder: (_, __) => SizedBox(width: context.rsi(12)),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.network(
                imageUrls[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ErrorPlaceholder(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: context.rsi(48),
          color: cs.outline,
        ),
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

    return AppSectionCard(
      title: '태그',
      icon: Icons.local_offer_outlined,
      child: Padding(
        padding: EdgeInsets.all(context.rsi(16)),
        child: Wrap(
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
    return AppSectionCard(
      title: '관련 자료',
      icon: Icons.link_rounded,
      child: Column(
        children: entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(bottom: context.rsi(8)),
            child: _RelatedCard(entry: entry),
          );
        }).toList(),
      ),
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.entry});

  final KnowledgeEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FieldKnowledgeDetailScreen(entryId: entry.id),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(context.rsi(12)),
          child: Row(
            children: [
              if (entry.primaryImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    entry.primaryImageUrl!,
                    width: context.rsi(60),
                    height: context.rsi(60),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: context.rsi(60),
                      height: context.rsi(60),
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.image_not_supported_outlined,
                          size: context.rsi(24)),
                    ),
                  ),
                )
              else
                Container(
                  width: context.rsi(60),
                  height: context.rsi(60),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.menu_book_outlined,
                      size: context.rsi(24), color: cs.primary),
                ),
              SizedBox(width: context.rsi(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style:
                          tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: context.rsi(4)),
                    Text(
                      KnowledgeCategories.entryKindLabel(entry),
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
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
    return AppSectionCard(
      title: '정보',
      icon: Icons.info_outlined,
      child: Padding(
        padding: EdgeInsets.all(context.rsi(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
