import 'package:flutter/material.dart';
import 'package:w0001/data/model/field_knowledge_models.dart';
import 'package:w0001/theme/app_colors.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 용어사전 상세 — 카드로 쪼개지 않은 사전 항목 레이아웃.
class TermDictionaryDetailView extends StatelessWidget {
  const TermDictionaryDetailView({
    super.key,
    required this.entry,
  });

  final KnowledgeEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final extras = entry.termExtras;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        context.rsi(20),
        context.rsi(8),
        context.rsi(20),
        MediaQuery.paddingOf(context).bottom + context.rsi(40),
      ),
      children: [
        // 표제어 블록
        _HeadwordBlock(entry: entry, extras: extras),
        SizedBox(height: context.rsi(22)),

        // 정의
        if (entry.content.trim().isNotEmpty) ...[
          Text(
            entry.content.trim(),
            style: tt.bodyLarge?.copyWith(
              height: 1.75,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
          SizedBox(height: context.rsi(22)),
        ],

        // 별칭 · 관련 용어 (한 흐름)
        if (extras != null &&
            (extras.aliases.isNotEmpty || extras.relatedTerms.isNotEmpty)) ...[
          _SoftDivider(color: cs.outlineVariant),
          SizedBox(height: context.rsi(16)),
          if (extras.aliases.isNotEmpty) ...[
            _InlineChipRow(
              label: '다른 말',
              values: extras.aliases,
              tone: _ChipTone.muted,
            ),
            SizedBox(height: context.rsi(14)),
          ],
          if (extras.relatedTerms.isNotEmpty) ...[
            _InlineChipRow(
              label: '관련어',
              values: extras.relatedTerms,
              tone: _ChipTone.accent,
            ),
            SizedBox(height: context.rsi(14)),
          ],
        ],

        // 태그
        if (entry.tags.isNotEmpty) ...[
          if (extras == null ||
              (extras.aliases.isEmpty && extras.relatedTerms.isEmpty)) ...[
            _SoftDivider(color: cs.outlineVariant),
            SizedBox(height: context.rsi(16)),
          ],
          Wrap(
            spacing: context.rsi(10),
            runSpacing: context.rsi(6),
            children: entry.tags.map((tag) {
              return Text(
                '#$tag',
                style: tt.labelMedium?.copyWith(
                  color: cs.primary.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
          SizedBox(height: context.rsi(20)),
        ],

        // 메타 푸터
        _SoftDivider(color: cs.outlineVariant),
        SizedBox(height: context.rsi(14)),
        Text(
          _metaLine(entry),
          style: tt.labelSmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  String _metaLine(KnowledgeEntry entry) {
    final parts = <String>['조회 ${entry.viewCount}회'];
    if (entry.updatedAt != null) {
      parts.add('수정 ${_formatDate(entry.updatedAt!)}');
    } else if (entry.createdAt != null) {
      parts.add('등록 ${_formatDate(entry.createdAt!)}');
    }
    return parts.join('  ·  ');
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

class _HeadwordBlock extends StatelessWidget {
  const _HeadwordBlock({
    required this.entry,
    required this.extras,
  });

  final KnowledgeEntry entry;
  final TermExtras? extras;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final field = extras?.field?.trim();
    final standard = extras?.standardName?.trim();
    final english = extras?.englishName?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                entry.title,
                style: tt.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  letterSpacing: -0.8,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (field != null && field.isNotEmpty) ...[
              SizedBox(width: context.rsi(10)),
              Container(
                margin: EdgeInsets.only(top: context.rsi(4)),
                padding: EdgeInsets.symmetric(
                  horizontal: context.rsi(10),
                  vertical: context.rsi(5),
                ),
                decoration: BoxDecoration(
                  color: AppColors.iconBadgeFill,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Text(
                  field,
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (standard != null &&
            standard.isNotEmpty &&
            standard != entry.title) ...[
          SizedBox(height: context.rsi(10)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '표준',
                style: tt.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: context.rsi(8)),
              Expanded(
                child: Text(
                  standard,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (english != null && english.isNotEmpty) ...[
          SizedBox(height: context.rsi(6)),
          Text(
            english,
            style: tt.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ],
    );
  }
}

enum _ChipTone { muted, accent }

class _InlineChipRow extends StatelessWidget {
  const _InlineChipRow({
    required this.label,
    required this.values,
    required this.tone,
  });

  final String label;
  final List<String> values;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isAccent = tone == _ChipTone.accent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: context.rsi(48),
          child: Padding(
            padding: EdgeInsets.only(top: context.rsi(6)),
            child: Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: context.rsi(8),
            runSpacing: context.rsi(8),
            children: values.map((value) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rsi(12),
                  vertical: context.rsi(6),
                ),
                decoration: BoxDecoration(
                  color: isAccent
                      ? cs.primary.withValues(alpha: 0.06)
                      : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isAccent
                        ? cs.primary.withValues(alpha: 0.18)
                        : AppColors.borderColor,
                  ),
                ),
                child: Text(
                  value,
                  style: tt.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isAccent ? cs.primary : AppColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: color.withValues(alpha: 0.55),
    );
  }
}
