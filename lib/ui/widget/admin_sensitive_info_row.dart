import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/util/copyable_display.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 관리자 — 마스킹·reveal·복사가 있는 민감정보 행.
class AdminSensitiveInfoRow extends StatelessWidget {
  const AdminSensitiveInfoRow({
    super.key,
    required this.label,
    required this.display,
    this.isRevealed = false,
    this.canReveal = false,
    this.revealing = false,
    this.onReveal,
  });

  final String label;
  final String display;
  final bool isRevealed;
  final bool canReveal;
  final bool revealing;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final canCopy = isRevealed && isCopyableDisplayValue(display);

    return Padding(
      padding: EdgeInsets.only(bottom: context.rsi(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.rsi(4)),
          Row(
            children: [
              Expanded(
                child: Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: tt.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isRevealed ? cs.error : cs.onSurface,
                  ),
                ),
              ),
              if (canReveal && onReveal != null && !isRevealed)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: context.rs(32),
                    minHeight: context.rs(32),
                  ),
                  tooltip: '전체 보기',
                  onPressed: revealing ? null : onReveal,
                  icon: revealing
                      ? SizedBox(
                          width: context.rs(18),
                          height: context.rs(18),
                          child: const HammerLoadingIndicator(size: 18),
                        )
                      : Icon(
                          Icons.visibility_outlined,
                          size: context.rs(20),
                          color: cs.onSurfaceVariant,
                        ),
                ),
              if (canCopy)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: context.rs(32),
                    minHeight: context.rs(32),
                  ),
                  tooltip: '복사',
                  onPressed: () => copyDisplayValue(
                    context,
                    label: label,
                    value: display,
                  ),
                  icon: Icon(
                    Icons.copy_rounded,
                    size: context.rs(18),
                    color: cs.primary,
                  ),
                ),
            ],
          ),
          if (isRevealed)
            Padding(
              padding: EdgeInsets.only(top: context.rsi(2)),
              child: Text(
                '전체 조회됨 · 화면을 닫으면 다시 마스킹됩니다.',
                style: tt.labelSmall?.copyWith(color: cs.error),
              ),
            ),
        ],
      ),
    );
  }
}
