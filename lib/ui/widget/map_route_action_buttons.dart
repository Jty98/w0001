import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

class MapRouteActionButtons extends StatelessWidget {
  const MapRouteActionButtons({
    super.key,
    required this.onKakao,
    required this.onTmap,
    this.onCopyAddress,
    this.compact = false,
  });

  final VoidCallback onKakao;
  final VoidCallback onTmap;
  final VoidCallback? onCopyAddress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cs = Theme.of(context).colorScheme;
        final tight = compact || constraints.maxWidth < context.rs(360);
        final copyWidth = tight ? context.rs(44) : context.rs(84);
        final verticalPad = tight ? context.rsi(8) : context.rsi(10);
        final kakaoLabel = tight ? '카카오' : '카카오 안내';
        final tmapLabel = tight ? 'T맵' : 'T맵 안내';

        return Row(
          children: [
            if (onCopyAddress != null) ...[
              SizedBox(
                width: copyWidth,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.symmetric(vertical: verticalPad),
                  ),
                  onPressed: onCopyAddress,
                  child: tight
                      ? const Icon(Icons.copy_rounded, size: 16)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.copy_rounded, size: 16),
                            SizedBox(width: 4),
                            Text('복사'),
                          ],
                        ),
                ),
              ),
              SizedBox(width: context.rsi(6)),
            ],
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(vertical: verticalPad),
                  backgroundColor: const Color(0xFFFFE812),
                  foregroundColor: Colors.black87,
                ),
                onPressed: onKakao,
                icon: const Icon(Icons.near_me_rounded, size: 16),
                label: Text(
                  kakaoLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: context.rs(tight ? 11 : 12),
                  ),
                ),
              ),
            ),
            SizedBox(width: context.rsi(6)),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(vertical: verticalPad),
                  backgroundColor: const Color(0xFF2E7DFF),
                  foregroundColor: Colors.white,
                ),
                onPressed: onTmap,
                icon: const Icon(Icons.navigation_rounded, size: 16),
                label: Text(
                  tmapLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: context.rs(tight ? 11 : 12),
                  ),
                ),
              ),
            ),
            if (!tight) ...[
              SizedBox(width: context.rsi(2)),
              Icon(Icons.route_rounded,
                  size: context.rsi(14), color: cs.primary),
            ],
          ],
        );
      },
    );
  }
}
