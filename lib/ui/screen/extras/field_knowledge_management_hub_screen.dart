import 'package:flutter/material.dart';
import 'package:w0001/data/model/field_knowledge_models.dart';
import 'package:w0001/ui/screen/extras/field_knowledge_list_screen.dart';
import 'package:w0001/util/responsive_layout.dart';

class FieldKnowledgeManagementHubScreen extends StatelessWidget {
  const FieldKnowledgeManagementHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 4 : 2;
    final ratio = width >= 900 ? 1.05 : 0.88;

    return Scaffold(
      appBar: AppBar(title: const Text('현장 지식 관리')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.rsi(16),
          context.rsi(12),
          context.rsi(16),
          MediaQuery.paddingOf(context).bottom + context.rsi(32),
        ),
        children: [
          SizedBox(height: context.rsi(20)),
          Text(
            '콘텐츠 유형',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: context.rsi(4)),
          Text(
            '자재와 용어를 연결하고, 실제 시공 사례를 교육 자료로 관리합니다.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SizedBox(height: context.rsi(12)),
          GridView.count(
            crossAxisCount: columns,
            childAspectRatio: ratio,
            crossAxisSpacing: context.rsi(12),
            mainAxisSpacing: context.rsi(12),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _KnowledgeFeatureCard(
                icon: Icons.inventory_2_outlined,
                title: '자재사전',
                description: '대표·상세 이미지, 특징, 주의사항과 현장 팁',
                accent: Theme.of(context).colorScheme.primary,
                onTap: () =>
                    _navigateToList(context, KnowledgeEntryType.material),
              ),
              _KnowledgeFeatureCard(
                icon: Icons.menu_book_outlined,
                title: '용어사전',
                description: '현장 용어 정의와 예시, 관련 자재 연결',
                accent: Theme.of(context).colorScheme.secondary,
                onTap: () => _navigateToList(context, KnowledgeEntryType.term),
              ),
              _KnowledgeFeatureCard(
                icon: Icons.compare_outlined,
                title: '시공사례',
                description: '베스트·워스트 사례 비교하며 작업 노하우 공유',
                accent: Colors.teal,
                onTap: () => _navigateToList(
                    context, KnowledgeEntryType.constructionCase),
              ),
              _KnowledgeFeatureCard(
                icon: Icons.construction_outlined,
                title: '공정 가이드',
                description: '시공 공정별 순서와 주의사항 단계별 가이드',
                accent: Colors.orange,
                onTap: () =>
                    _navigateToList(context, KnowledgeEntryType.processGuide),
              ),
            ],
          ),
          SizedBox(height: context.rsi(20)),
        ],
      ),
    );
  }

  static void _navigateToList(BuildContext context, KnowledgeEntryType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FieldKnowledgeListScreen(type: type),
      ),
    );
  }
}

class _KnowledgeFeatureCard extends StatelessWidget {
  const _KnowledgeFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(context.rsi(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(context.rsi(9)),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: context.rsi(24)),
                  ),
                  const Spacer(),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              SizedBox(height: context.rsi(4)),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
