import 'package:flutter/material.dart';
import 'package:w0001/data/model/field_knowledge_models.dart';
import 'package:w0001/theme/app_colors.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 용어사전 전용 카드 — 표제어 중심의 사전 항목 미리보기.
class TermDictionaryCard extends StatelessWidget {
  const TermDictionaryCard({
    super.key,
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
    final extras = entry.termExtras;
    final standard = extras?.standardName?.trim();
    final field = extras?.field?.trim();
    final hasStandard =
        standard != null && standard.isNotEmpty && standard != entry.title;
    final aliases = extras?.aliases ?? const <String>[];

    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            context.rsi(16),
            context.rsi(14),
            context.rsi(12),
            context.rsi(14),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              height: 1.2,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        if (field != null && field.isNotEmpty) ...[
                          SizedBox(width: context.rsi(8)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.rsi(9),
                              vertical: context.rsi(4),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.iconBadgeFill,
                              borderRadius: BorderRadius.circular(999),
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
                    if (hasStandard) ...[
                      SizedBox(height: context.rsi(6)),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '표준  ',
                              style: tt.labelMedium?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: standard,
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.primary,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (entry.content.trim().isNotEmpty) ...[
                      SizedBox(height: context.rsi(10)),
                      Text(
                        entry.content.trim(),
                        style: tt.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.55,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (aliases.isNotEmpty) ...[
                      SizedBox(height: context.rsi(10)),
                      Text(
                        aliases.take(4).join(' · '),
                        style: tt.labelMedium?.copyWith(
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
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
                  visualDensity: VisualDensity.compact,
                )
              else
                Padding(
                  padding: EdgeInsets.only(top: context.rsi(4)),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary.withValues(alpha: 0.55),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
