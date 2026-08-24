import 'package:flutter/material.dart';
import 'package:w0001/data/model/field_knowledge_models.dart';
import 'package:w0001/ui/screen/extras/field_knowledge_list_screen.dart';
import 'package:w0001/ui/screen/extras/hardware_dictionary_style.dart';
import 'package:w0001/util/responsive_layout.dart';

class HardwareDictionaryHubScreen extends StatelessWidget {
  const HardwareDictionaryHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('철물 사전')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.rsi(16),
          context.rsi(12),
          context.rsi(16),
          MediaQuery.paddingOf(context).bottom + context.rsi(32),
        ),
        children: [
          Text(
            '자재와 공구 중에서 선택하세요.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          SizedBox(height: context.rsi(16)),
          _HardwareKindRow(
            kind: HardwareDictionaryKind.material,
            onTap: () => _openList(context, HardwareDictionaryKind.material),
          ),
          SizedBox(height: context.rsi(10)),
          _HardwareKindRow(
            kind: HardwareDictionaryKind.tool,
            onTap: () => _openList(context, HardwareDictionaryKind.tool),
          ),
        ],
      ),
    );
  }

  static void _openList(
    BuildContext context,
    HardwareDictionaryKind kind,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FieldKnowledgeListScreen(
          type: KnowledgeEntryType.material,
          hardwareKind: kind,
        ),
      ),
    );
  }
}

class _HardwareKindRow extends StatelessWidget {
  const _HardwareKindRow({
    required this.kind,
    required this.onTap,
  });

  final HardwareDictionaryKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = HardwareDictionaryStyle.accentFor(kind);

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(14),
            vertical: context.rsi(14),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Icon(
                HardwareDictionaryStyle.iconForKind(kind),
                color: accent,
                size: context.rsi(22),
              ),
              SizedBox(width: context.rsi(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.label,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: context.rsi(2)),
                    Text(
                      kind.description,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
