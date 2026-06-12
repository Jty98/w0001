import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 인력 관리·현장 초대 등에서 공통으로 쓰는 검색바 + 찾기 버튼.
class HumanWorkerSearchBar extends StatelessWidget {
  const HumanWorkerSearchBar({
    super.key,
    required this.searchController,
    required this.onChanged,
    required this.workerCount,
    required this.onBrowseTap,
    this.hintText = '이름으로 검색',
    this.browseLabel = '찾기',
    this.padding,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onChanged;
  final int workerCount;
  final VoidCallback onBrowseTap;
  final String hintText;
  final String browseLabel;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: padding ??
          EdgeInsets.fromLTRB(
            context.rsi(16),
            context.rsi(6),
            context.rsi(16),
            context.rsi(6),
          ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hintText,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: context.rsi(8),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: context.rs(20),
                  color: cs.onSurfaceVariant,
                ),
                filled: true,
                fillColor: cs.surface.withValues(alpha: 0.65),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: cs.primary.withValues(alpha: 0.55)),
                ),
              ),
              style: tt.bodyMedium,
            ),
          ),
          SizedBox(width: context.rsi(8)),
          SizedBox(
            height: context.rs(42),
            child: OutlinedButton.icon(
              onPressed: workerCount == 0 ? null : onBrowseTap,
              icon: Icon(Icons.view_list_rounded, size: context.rs(17)),
              label: Text(browseLabel),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.symmetric(horizontal: context.rsi(10)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
