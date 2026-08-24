import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

class KnowledgeFeatureCard extends StatelessWidget {
  const KnowledgeFeatureCard({
    super.key,
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
