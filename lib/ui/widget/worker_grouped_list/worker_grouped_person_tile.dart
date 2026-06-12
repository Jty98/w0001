import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/worker_grouped_list/worker_grouped_list_layout.dart';
import 'package:w0001/util/responsive_layout.dart';

class WorkerGroupedPersonTile extends StatelessWidget {
  const WorkerGroupedPersonTile({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final String name;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tileSpacing = context.rsi(kWorkerGroupedPersonTileSpacing);
    final tileExtent = context.rs(kWorkerGroupedPersonTileExtent);
    return Container(
      margin: EdgeInsets.only(bottom: tileSpacing),
      height: tileExtent - tileSpacing,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(context.rsi(12)),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(context.rsi(12)),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(14),
              context.rsi(6),
              context.rsi(12),
              context.rsi(11),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: context.rsi(4)),
                      Text(
                        subtitle,
                        style: tt.labelSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  SizedBox(width: context.rsi(4)),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
