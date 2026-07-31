import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/util/responsive_layout.dart';

Dialog saveDialog({
  required String text,
  String? title,
  double? width,
  Widget? child,
  TextStyle? textStyle,
  TextStyle? titleStyle,
}) {
  return Dialog(
    child: Builder(
      builder: (context) {
        final tt = Theme.of(context).textTheme;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.rs(10)),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(context.rs(10)),
                child: Text(
                  title ?? '알림',
                  style: titleStyle ?? tt.titleMedium,
                ),
              ),
              Text(text, style: textStyle ?? tt.bodyLarge),
              child ?? const SizedBox.shrink(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      context.pop();
                    },
                    child: Text(
                      '확인',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    ),
  );
}

/// 현장 요약 등 여러 페이지를 넘기며 볼 때 쓰는 다이얼로그.
Dialog pageViewDialog({
  required String text,
  String? title,
  double? height,
  List<Widget>? children,
  TextStyle? textStyle,
  TextStyle? titleStyle,
}) {
  return Dialog(
    clipBehavior: Clip.antiAlias,
    child: Builder(
      builder: (context) {
        final mq = MediaQuery.of(context);
        final size = mq.size;
        final compact = ResponsiveLayout.isCompact(size);
        final insetH = context.rs(compact ? 14 : 20);
        final maxDialogW = math.min(
          size.width - insetH * 2,
          ResponsiveLayout.contentMaxWidth(context) + context.rs(32),
        );
        final availH = size.height - mq.padding.top - mq.padding.bottom;
        final pageH = height ??
            (availH * (compact ? 0.62 : 0.56)).clamp(
              context.rs(280),
              context.rs(compact ? 420 : 500),
            );
        final pages = children ?? const <Widget>[];

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxDialogW),
          child: _PageViewDialogBody(
            title: title,
            text: text,
            pageHeight: pageH,
            pages: pages,
            textStyle: textStyle,
            titleStyle: titleStyle,
          ),
        );
      },
    ),
  );
}

class _PageViewDialogBody extends StatefulWidget {
  const _PageViewDialogBody({
    required this.title,
    required this.text,
    required this.pageHeight,
    required this.pages,
    this.textStyle,
    this.titleStyle,
  });

  final String? title;
  final String text;
  final double pageHeight;
  final List<Widget> pages;
  final TextStyle? textStyle;
  final TextStyle? titleStyle;

  @override
  State<_PageViewDialogBody> createState() => _PageViewDialogBodyState();
}

class _PageViewDialogBodyState extends State<_PageViewDialogBody> {
  late final PageController _pageController;
  var _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final compact = ResponsiveLayout.isCompact(MediaQuery.sizeOf(context));
    final pages = widget.pages;

    Widget pageBody;
    if (pages.isEmpty) {
      pageBody = const SizedBox.shrink();
    } else if (pages.length == 1) {
      pageBody = SingleChildScrollView(
        padding: ResponsiveLayout.symmetric(
          context,
          horizontal: 12,
          vertical: 4,
        ),
        child: pages.first,
      );
    } else {
      pageBody = Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              children: [
                for (final page in pages)
                  SingleChildScrollView(
                    padding: ResponsiveLayout.symmetric(
                      context,
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: page,
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: context.rsi(4)),
            child: Text(
              '${_pageIndex + 1} / ${pages.length} · 옆으로 밀어 보기',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.rs(12)),
        color: cs.surfaceContainerHigh,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(16),
              context.rsi(compact ? 12 : 14),
              context.rsi(16),
              context.rsi(6),
            ),
            child: Column(
              children: [
                Text(
                  widget.title ?? '알림',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: widget.titleStyle ??
                      tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (widget.text.isNotEmpty) ...[
                  SizedBox(height: context.rsi(6)),
                  Text(
                    widget.text,
                    textAlign: TextAlign.center,
                    style: widget.textStyle ??
                        tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            height: widget.pageHeight,
            width: double.infinity,
            child: pageBody,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(8),
              0,
              context.rsi(8),
              context.rsi(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(
                    '확인',
                    style: TextStyle(color: cs.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
