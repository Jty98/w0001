import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/ui/screen/announcements/announcement_image_strip_embed.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_rich_quill.dart';
import 'package:w0001/ui/widget/network_image_viewer_sheet.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 공지 본문 표시 — Quill 저장분은 리치 텍스트로, 그 외는 기존 텍스트·이미지 열.
class WorkerAnnouncementBlocksDisplay extends StatefulWidget {
  const WorkerAnnouncementBlocksDisplay({
    super.key,
    required this.blocks,
    this.textStyle,

    /// true면 Quill 단일 이미지 탭 시 복사·저장·확대 메뉴를 띄우지 않음(목록 미리보기용).
    this.suppressInteractiveImageMenu = false,

    /// Quill 에디터 높이. null이면 화면 비율로 자동(최소 높이 보장).
    this.quillViewportHeight,

    /// [quillViewportHeight]가 null일 때 화면 높이 대비 비율 (기본 0.52).
    this.quillViewportHeightFactor = 0.52,

    /// deprecated — [quillViewportHeight] 사용 권장.
    this.quillViewportMaxHeight,
  });

  final List<WorkerAnnouncementBlock> blocks;
  final TextStyle? textStyle;
  final bool suppressInteractiveImageMenu;
  final double? quillViewportHeight;
  final double quillViewportHeightFactor;
  @Deprecated('Use quillViewportHeight')
  final double? quillViewportMaxHeight;

  @override
  State<WorkerAnnouncementBlocksDisplay> createState() =>
      _WorkerAnnouncementBlocksDisplayState();
}

class _WorkerAnnouncementBlocksDisplayState
    extends State<WorkerAnnouncementBlocksDisplay> {
  QuillController? _quillRead;
  ScrollController? _quillScroll;
  late final FocusNode _quillReadFocus;
  late QuillEditorConfig _readEditorConfig;

  QuillEditorConfig _buildReadEditorConfig(BuildContext context) {
    return QuillEditorConfig(
      showCursor: false,
      padding: EdgeInsets.zero,
      scrollable: true,
      expands: true,
      customStyles: WorkerAnnouncementRichQuill.quillDefaultStyles(context),
      textSpanBuilder: WorkerAnnouncementRichQuill.safeTextSpanBuilder(context),
      embedBuilders: announcementQuillEmbedBuilders(
        imageEmbedConfig: QuillEditorImageEmbedConfig(
          onImageClicked: (url) {
            final u = url.trim();
            if (u.isEmpty) return;
            showNetworkImageViewerSheet(
              context,
              urls: [u],
              initialIndex: 0,
            );
          },
        ),
        videoEmbedConfig: null,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _quillReadFocus = FocusNode(canRequestFocus: false, skipTraversal: true);
    _syncQuillReader();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _readEditorConfig = _buildReadEditorConfig(context);
  }

  @override
  void didUpdateWidget(WorkerAnnouncementBlocksDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final blocksChanged = !listEquals(oldWidget.blocks, widget.blocks);
    final menuChanged = oldWidget.suppressInteractiveImageMenu !=
        widget.suppressInteractiveImageMenu;
    if (menuChanged) {
      _readEditorConfig = _buildReadEditorConfig(context);
    }
    if (blocksChanged || menuChanged) {
      _disposeQuillReader();
      _syncQuillReader();
    }
  }

  void _syncQuillReader() {
    if (!WorkerAnnouncementQuillCodec.blocksLookLikeStoredQuill(
        widget.blocks)) {
      return;
    }
    final doc = WorkerAnnouncementQuillCodec.decodeToDocument(widget.blocks);
    _quillScroll = ScrollController();
    _quillRead = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  void _disposeQuillReader() {
    _quillRead?.dispose();
    _quillRead = null;
    _quillScroll?.dispose();
    _quillScroll = null;
  }

  @override
  void dispose() {
    _disposeQuillReader();
    _quillReadFocus.dispose();
    super.dispose();
  }

  double _resolveQuillViewportHeight(
      BuildContext context, BoxConstraints constraints) {
    if (widget.quillViewportHeight != null) {
      return widget.quillViewportHeight!;
    }
    if (constraints.maxHeight.isFinite && constraints.maxHeight >= 240) {
      return constraints.maxHeight;
    }
    final screenH = MediaQuery.sizeOf(context).height;
    final legacyMax = widget.quillViewportMaxHeight;
    final fromFactor = screenH * widget.quillViewportHeightFactor;
    final h = legacyMax ?? fromFactor;
    return h.clamp(280.0, screenH * 0.72);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportH = _resolveQuillViewportHeight(context, constraints);

        if (WorkerAnnouncementQuillCodec.blocksLookLikeStoredQuill(
            widget.blocks)) {
          final ops =
              WorkerAnnouncementQuillCodec.decodeDeltaOps(widget.blocks);
          if (ops != null && _deltaHasRichEmbeds(ops)) {
            final manual = _QuillDeltaBlocksColumn.tryBuild(
              context: context,
              ops: ops,
              textStyle: widget.textStyle,
            );
            if (manual != null) {
              return SizedBox(
                height: viewportH,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: manual,
                ),
              );
            }
          }
        }
        if (_quillRead != null && _quillScroll != null) {
          return SizedBox(
            height: viewportH,
            child: QuillEditor(
              key: ValueKey<QuillController>(_quillRead!),
              focusNode: _quillReadFocus,
              scrollController: _quillScroll!,
              controller: _quillRead!,
              config: _readEditorConfig,
            ),
          );
        }
        return SizedBox(
          height: viewportH,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: _LegacyBlocksColumn(
              blocks: widget.blocks,
              textStyle: widget.textStyle,
            ),
          ),
        );
      },
    );
  }
}

bool _deltaHasRichEmbeds(List<dynamic> ops) {
  for (final op in ops) {
    if (op is! Map) continue;
    final ins = op['insert'];
    if (ins is! Map) continue;
    if (ins.containsKey(AnnouncementImageStripEmbed.type) ||
        ins.containsKey('image')) {
      return true;
    }
  }
  return false;
}

/// Quill 읽기 전용 에디터 대신 텍스트·콜라주를 직접 그려 회색 빈 줄을 막는다.
class _QuillDeltaBlocksColumn extends StatelessWidget {
  const _QuillDeltaBlocksColumn._({
    required this.ops,
    this.textStyle,
  });

  final List<dynamic> ops;
  final TextStyle? textStyle;

  static Widget? tryBuild({
    required BuildContext context,
    required List<dynamic> ops,
    TextStyle? textStyle,
  }) {
    final column = _QuillDeltaBlocksColumn._(ops: ops, textStyle: textStyle);
    final children = column._buildChildren(context);
    if (children.isEmpty) return null;
    return column._wrap(context, children);
  }

  List<Widget> _buildChildren(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final bodyStyle = textStyle ?? tt.bodyLarge;
    final children = <Widget>[];

    for (final op in ops) {
      if (op is! Map) continue;
      final ins = op['insert'];
      if (ins is String) {
        final t = ins.replaceAll('\u200b', '');
        if (t.replaceAll(RegExp(r'\s'), '').isEmpty) continue;
        children.add(SelectableText(t, style: bodyStyle));
        children.add(SizedBox(height: context.rsi(10)));
        continue;
      }
      if (ins is! Map) continue;

      final stripRaw = ins[AnnouncementImageStripEmbed.type];
      if (stripRaw != null) {
        final data = AnnouncementImageStripData.tryParseJson(
          stripRaw is String ? stripRaw : jsonEncode(stripRaw),
        );
        if (data != null && data.urls.isNotEmpty) {
          children.add(AnnouncementCollageImageStrip(urls: data.urls));
          children.add(SizedBox(height: context.rsi(12)));
        }
        continue;
      }

      final imageRaw = ins['image'];
      if (imageRaw != null) {
        final u = imageRaw.toString().trim();
        if (u.isNotEmpty) {
          children.add(
            GestureDetector(
              onTap: () => showNetworkImageViewerSheet(
                context,
                urls: [u],
                initialIndex: 0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: announcementEmbedImage(
                    u,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          );
          children.add(SizedBox(height: context.rsi(12)));
        }
      }
    }
    return children;
  }

  Widget _wrap(BuildContext context, List<Widget> children) {
    if (children.last is SizedBox) children.removeLast();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = _buildChildren(context);
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return _wrap(context, children);
  }
}

class _LegacyBlocksColumn extends StatelessWidget {
  const _LegacyBlocksColumn({
    required this.blocks,
    this.textStyle,
  });

  final List<WorkerAnnouncementBlock> blocks;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final bodyStyle = textStyle ?? tt.bodyLarge;

    final children = <Widget>[];
    for (final b in blocks) {
      switch (b) {
        case WorkerAnnouncementTextBlock(:final text):
          if (WorkerAnnouncementQuillCodec.isQuillEnvelopeText(text)) {
            continue;
          }
          if (text.trim().isEmpty) continue;
          children.add(
            SelectableText(
              text.trim(),
              style: bodyStyle,
            ),
          );
          children.add(SizedBox(height: context.rsi(14)));
        case WorkerAnnouncementImageBlock(:final url):
          final u = url.trim();
          if (u.isEmpty) continue;
          children.add(
            GestureDetector(
              onTap: () => showNetworkImageViewerSheet(
                context,
                urls: [u],
                initialIndex: 0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: announcementEmbedImage(
                    u,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Skeletonizer(
                        enabled: true,
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: ColoredBox(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: Center(
                              child: Text(
                                '이미지',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          children.add(SizedBox(height: context.rsi(14)));
      }
    }

    if (children.isEmpty) {
      if (WorkerAnnouncementQuillCodec.blocksLookLikeStoredQuill(blocks)) {
        final preview =
            WorkerAnnouncementQuillCodec.blocksPlainTextPreview(blocks);
        if (preview.isNotEmpty) {
          return SelectableText(
            preview,
            style: bodyStyle,
          );
        }
      }
      return Text(
        '(내용 없음)',
        style: bodyStyle?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (children.last is SizedBox) {
      children.removeLast();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
