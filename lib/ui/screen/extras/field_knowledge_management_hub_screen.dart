import 'package:flutter/material.dart';
import 'package:w0001/data/model/field_knowledge_models.dart';
import 'package:w0001/ui/screen/extras/field_knowledge_list_screen.dart';
import 'package:w0001/ui/screen/extras/hardware_dictionary_hub_screen.dart';
import 'package:w0001/ui/screen/extras/widgets/knowledge_feature_card.dart';
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
            '철물(자재·공구)과 용어를 연결하고, 실제 시공 사례를 교육 자료로 관리합니다.',
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
              KnowledgeFeatureCard(
                icon: Icons.hardware_outlined,
                title: '철물 사전',
                description: '자재와 공구의 대표·상세 이미지, 특징, 주의사항과 현장 팁',
                accent: Theme.of(context).colorScheme.primary,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HardwareDictionaryHubScreen(),
                  ),
                ),
              ),
              KnowledgeFeatureCard(
                icon: Icons.menu_book_outlined,
                title: '용어사전',
                description: '현장 용어 정의와 예시, 관련 철물 연결',
                accent: Theme.of(context).colorScheme.secondary,
                onTap: () => _navigateToList(context, KnowledgeEntryType.term),
              ),
              KnowledgeFeatureCard(
                icon: Icons.compare_outlined,
                title: '시공사례',
                description: '베스트·워스트 사례 비교하며 작업 노하우 공유',
                accent: Colors.teal,
                onTap: () => _navigateToList(
                    context, KnowledgeEntryType.constructionCase),
              ),
              KnowledgeFeatureCard(
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
