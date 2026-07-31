import 'package:flutter/material.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/util/responsive_layout.dart';

Future<void> showTermsDetailSheet(
  BuildContext context, {
  required TermDetail detail,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final tt = Theme.of(ctx).textTheme;
      final summary = detail.summary;
      final bottomInset = MediaQuery.viewPaddingOf(ctx).bottom;

      return DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        expand: false,
        builder: (sheetCtx, scrollController) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(sheetCtx.rs(20)),
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.14),
                  blurRadius: sheetCtx.rs(18),
                  offset: Offset(0, -sheetCtx.rs(4)),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: sheetCtx.rsi(10)),
                Center(
                  child: Container(
                    width: sheetCtx.rs(40),
                    height: sheetCtx.rs(4),
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(sheetCtx.rs(99)),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    sheetCtx.rsi(20),
                    sheetCtx.rsi(16),
                    sheetCtx.rsi(20),
                    sheetCtx.rsi(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: sheetCtx.rs(40),
                        height: sheetCtx.rs(40),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(sheetCtx.rs(12)),
                        ),
                        child: Icon(
                          Icons.article_outlined,
                          color: cs.onPrimaryContainer,
                          size: sheetCtx.rs(22),
                        ),
                      ),
                      SizedBox(width: sheetCtx.rsi(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.displayTitle,
                              style: tt.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: sheetCtx.rsi(4)),
                            Text(
                              '버전 v${summary.version}',
                              style: tt.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: sheetCtx.rsi(20)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(sheetCtx.rs(14)),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Scrollbar(
                        controller: scrollController,
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: EdgeInsets.all(sheetCtx.rsi(16)),
                          child: SelectableText(
                            detail.content.trim().isEmpty
                                ? '약관 본문이 없습니다.'
                                : detail.content.trim(),
                            style: tt.bodyMedium?.copyWith(height: 1.55),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border(
                      top: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      sheetCtx.rsi(20),
                      sheetCtx.rsi(12),
                      sheetCtx.rsi(20),
                      sheetCtx.rsi(12) + bottomInset,
                    ),
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      style: FilledButton.styleFrom(
                        minimumSize: Size.fromHeight(sheetCtx.rs(52)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(sheetCtx.rs(12)),
                        ),
                      ),
                      child: const Text('확인'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
