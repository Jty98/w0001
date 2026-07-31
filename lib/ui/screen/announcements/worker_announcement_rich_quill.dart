import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:w0001/theme/app_input_styles.dart';
import 'package:w0001/ui/screen/announcements/announcement_image_strip_embed.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';
import 'package:w0001/ui/widget/image_upload_progress_dialog.dart';
import 'package:w0001/util/image_attachment/image_upload_result.dart';
import 'package:w0001/util/image_attachment/upload_image_remote.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 공지·작업지시 등 Quill 리치 텍스트 공통: 툴바·에디터·이미지 삽입·저장 전 업로드.
///
/// **편집 화면** (갤러리 첨부 → 로컬만, 저장 시 업로드):
/// - [AdminWorkerAnnouncementEditScreen]
/// - [_PlaceWorkInstructionEditorPage] (`place_work_instruction_editor_sheet.dart`)
///
/// **읽기 전용**: [WorkerAnnouncementBlocksDisplay]
abstract final class WorkerAnnouncementRichQuill {
  WorkerAnnouncementRichQuill._();

  static ImagePicker picker() => ImagePicker();

  static QuillEditorConfig editorConfig({
    String? placeholder,
    EdgeInsetsGeometry? padding,
    bool scrollable = true,
    bool autoFocus = false,
    bool expands = false,
    DefaultStyles? customStyles,
    TextSpanBuilder? textSpanBuilder,
  }) {
    return QuillEditorConfig(
      placeholder: placeholder,
      padding: padding ?? EdgeInsets.zero,
      scrollable: scrollable,
      autoFocus: autoFocus,
      expands: expands,
      customStyles: customStyles,
      textSpanBuilder: textSpanBuilder ?? defaultSpanBuilder,
      embedBuilders: announcementQuillEmbedBuilders(
        imageEmbedConfig: const QuillEditorImageEmbedConfig(),
        videoEmbedConfig: null,
      ),
    );
  }

  /// 툴바 — [afterToolbarButtonPressed]에 보통 [FocusNode.requestFocus].
  static QuillSimpleToolbarConfig toolbarConfig({
    required Future<String?> Function(BuildContext context) onRequestPickImage,
    VoidCallback? afterToolbarButtonPressed,
  }) {
    return QuillSimpleToolbarConfig(
      multiRowsDisplay: false,
      showDividers: false,
      showFontFamily: false,
      showItalicButton: false,
      showStrikeThrough: false,
      showInlineCode: false,
      showColorButton: false,
      showBackgroundColorButton: false,

      /// 붙여넣기·외부 델타로 들어온 투명 색 등 복구용(본문 색 버튼은 끔).
      showClearFormat: true,
      showSmallButton: false,
      showHeaderStyle: false,
      showListNumbers: false,
      showListBullets: false,
      showListCheck: false,
      showCodeBlock: false,
      showQuote: false,
      showIndent: false,
      showLink: false,
      showUndo: false,
      showRedo: false,
      showSearchButton: false,
      showSubscript: false,
      showSuperscript: false,
      showAlignmentButtons: true,
      showJustifyAlignment: false,
      showFontSize: false,
      showBoldButton: true,
      showUnderLineButton: true,
      embedButtons: FlutterQuillEmbeds.toolbarButtons(
        imageButtonOptions: QuillToolbarImageButtonOptions(
          imageButtonConfig: QuillToolbarImageConfig(
            onRequestPickImage: onRequestPickImage,
          ),
        ),
        videoButtonOptions: null,
        cameraButtonOptions: null,
      ),
      buttonOptions: QuillSimpleToolbarButtonOptions(
        base: QuillToolbarBaseButtonOptions(
          afterButtonPressed: afterToolbarButtonPressed,
        ),
        selectAlignmentButtons: const QuillToolbarSelectAlignmentButtonOptions(
          showJustifyAlignment: false,
          tooltips: QuillSelectAlignmentValues<String>(
            leftAlignment: '왼쪽 정렬',
            centerAlignment: '가운데 정렬',
            rightAlignment: '오른쪽 정렬',
            justifyAlignment: '',
          ),
        ),
      ),
    );
  }

  /// Quill 본문 — 투명·SCDream 상속 방지.
  static DefaultStyles quillDefaultStyles(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final body = AppInputStyles.fieldText(
      context,
      designFontSize: 16,
      height: 1.45,
    );
    const h = HorizontalSpacing(0, 0);
    const v = VerticalSpacing(0, 0);
    return DefaultStyles(
      color: cs.onSurface,
      paragraph: DefaultTextBlockStyle(body, h, v, v, null),
      placeHolder: DefaultTextBlockStyle(
        body.copyWith(
          inherit: false,
          color: cs.onSurfaceVariant.withValues(alpha: 0.72),
          fontSize: body.fontSize ?? 16,
          textBaseline: body.textBaseline ?? TextBaseline.alphabetic,
        ),
        h,
        v,
        v,
        null,
      ),
    );
  }

  static TextSpanBuilder safeTextSpanBuilder(BuildContext context) {
    return (
      BuildContext _,
      Node node,
      int nodeOffset,
      String text,
      TextStyle? style,
      GestureRecognizer? recognizer,
    ) {
      return TextSpan(
        text: text,
        style: AppInputStyles.visibleTextStyle(context, style),
        recognizer: recognizer,
        mouseCursor: recognizer != null ? SystemMouseCursors.click : null,
      );
    };
  }

  /// 갤러리에서 고른 로컬 이미지를 **즉시** 업로드한다. (일반 Quill 편집에서는 사용하지 않음)
  @Deprecated('Use galleryPickWorkflow + prepareDocumentForSave on save')
  static Future<List<String>> pickAndUploadGalleryDisplayUrls({
    required ImagePicker picker,
    required bool Function() mounted,
    int imageQuality = 88,
    ImageUploadCategory uploadCategory = ImageUploadCategory.announcementImage,
    void Function(int current, int total)? onProgress,
  }) async {
    final imgs = await picker.pickMultiImage(imageQuality: imageQuality);
    if (imgs.isEmpty) return [];
    final urls = <String>[];
    final total = imgs.length;
    for (var i = 0; i < imgs.length; i++) {
      onProgress?.call(i + 1, total);
      final res = await uploadLocalImageFile(
        imgs[i].path,
        category: uploadCategory,
      );
      if (!mounted()) return urls;
      urls.add(res.displayUrl);
    }
    return urls;
  }

  /// [urls] — 1장은 단일 임베드, 2장 이상은 카카오톡형 콜라주 블록 1개.
  static Future<void> insertImageUrlsAtCursor({
    required QuillController controller,
    required BuildContext context,
    required List<String> urls,
    required bool Function() mounted,
    bool stripLayoutWhenMultiple = true,
  }) async {
    if (urls.isEmpty) return;
    if (!stripLayoutWhenMultiple || urls.length == 1) {
      for (final u in urls) {
        if (!mounted()) return;
        insertSingleImageEmbedAtCursor(controller: controller, imageUrl: u);
      }
      scheduleCursorAfterEmbedInsert(controller);
      return;
    }
    if (!mounted()) return;
    final cursor = safeInsertOffset(controller);
    final embed = AnnouncementImageStripEmbed.create(
      urls: urls,
      mode: AnnouncementImageStripMode.grid,
    );
    controller.replaceText(
      cursor,
      0,
      embed,
      null,
      ignoreFocus: true,
    );
    _finalizeEmbedInsertion(controller, cursor);
    scheduleCursorAfterEmbedInsert(controller);
    return;
  }

  /// 임베드 삽입·업로드 다이얼로그 닫힘 뒤에도 커서가 임베드 앞(0)으로 돌아가
  /// 입력 시 이미지가 덮이지 않도록 문서 끝으로 되돌린다.
  static void scheduleCursorAfterEmbedInsert(QuillController controller) {
    void apply() {
      final end = controller.document.length;
      if (end <= 0) return;
      final sel = TextSelection.collapsed(offset: end);
      if (controller.selection.baseOffset != end ||
          controller.selection.extentOffset != end) {
        controller.updateSelection(sel, ChangeSource.local);
      }
    }

    apply();
    SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    SchedulerBinding.instance.scheduleFrameCallback((_) => apply());
  }

  /// 이미지·콜라주 임베드 바로 뒤에 줄바꿈을 넣고 커서를 그 다음으로 둔다.
  ///
  /// [toPlainText]는 임베드를 빈 문자열로 처리해 문서 오프셋과 맞지 않으므로
  /// 줄바꿈 존재 여부를 plain text로 검사하지 않는다.
  static void _finalizeEmbedInsertion(
    QuillController controller,
    int embedIndex,
  ) {
    final afterEmbed = (embedIndex + 1).clamp(0, controller.document.length);
    controller.replaceText(
      afterEmbed,
      0,
      '\n',
      TextSelection.collapsed(offset: afterEmbed + 1),
      ignoreFocus: true,
    );
  }

  /// 잘못된 selection·키보드 레이아웃 변화 후에도 삽입 위치가 문서 밖으로 나가지 않게 한다.
  static int safeInsertOffset(QuillController controller) {
    final len = controller.document.length;
    if (len <= 0) return 0;
    final sel = controller.selection;
    if (!sel.isValid) {
      return len;
    }
    return sel.baseOffset.clamp(0, len);
  }

  /// 이미지 임베드 뒤 줄바꿈을 넣어 이후 텍스트 입력 시 임베드가 덮이지 않게 한다.
  static void insertSingleImageEmbedAtCursor({
    required QuillController controller,
    required String imageUrl,
  }) {
    final url = imageUrl.trim();
    if (url.isEmpty) return;
    final cursor = safeInsertOffset(controller);
    controller.replaceText(
      cursor,
      0,
      BlockEmbed.image(url),
      null,
      ignoreFocus: true,
    );
    _finalizeEmbedInsertion(controller, cursor);
  }

  /// 툴바 [onRequestPickImage] — 갤러리에서 고른 **로컬 경로**만 본문에 넣는다.
  /// 서버 업로드는 저장 시 [WorkerAnnouncementQuillCodec.uploadLocalImagesInDocument]에서 한다.
  static Future<String?> galleryPickWorkflow({
    required BuildContext context,
    required QuillController controller,
    required ImagePicker picker,
    required bool Function() mounted,
    required bool uploadingGuard,
    void Function(bool uploading)? setUploading,
    bool stripLayoutWhenMultiple = true,
  }) async {
    if (uploadingGuard) return null;
    if (!context.mounted) return null;
    setUploading?.call(true);
    try {
      final imgs = await picker.pickMultiImage(imageQuality: 88);
      if (!mounted()) return null;
      if (imgs.isEmpty) return null;
      final paths = imgs
          .map((e) => e.path.trim())
          .where((p) => p.isNotEmpty)
          .toList(growable: false);
      if (paths.isEmpty) return null;
      await insertImageUrlsAtCursor(
        controller: controller,
        context: context,
        urls: paths,
        mounted: mounted,
        stripLayoutWhenMultiple: stripLayoutWhenMultiple,
      );
      if (mounted()) {
        scheduleCursorAfterEmbedInsert(controller);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 첨부 실패: $e')),
        );
      }
    } finally {
      if (mounted()) setUploading?.call(false);
    }
    return null;
  }

  /// 저장·적용 직전 — 문서에 로컬 이미지가 있으면 업로드 후 URL로 치환한 문서를 반환한다.
  static Future<Document> prepareDocumentForSave({
    required BuildContext context,
    required Document doc,
    required bool Function() mounted,
    ImageUploadCategory uploadCategory = ImageUploadCategory.announcementImage,
  }) async {
    if (!WorkerAnnouncementQuillCodec.documentHasLocalImages(doc)) {
      return doc;
    }
    if (!context.mounted || !mounted()) return doc;
    return runWithImageUploadProgressDialog(
      context: context,
      body: (setMessage) {
        return WorkerAnnouncementQuillCodec.uploadLocalImagesInDocument(
          doc,
          category: uploadCategory,
          onProgress: (current, total) =>
              setMessage('이미지 업로드 중… ($current/$total)'),
        );
      },
    );
  }

  /// 현장·공지 등 — URL 목록을 한 번에 삽입(업로드 없음).
  static Future<void> insertImageUrlsWithProgress({
    required BuildContext context,
    required QuillController controller,
    required List<String> urls,
    required bool Function() mounted,
    bool stripLayoutWhenMultiple = true,
    String progressLabel = '이미지 첨부 중…',
  }) async {
    if (urls.isEmpty || !context.mounted) return;
    await runWithImageUploadProgressDialog<void>(
      context: context,
      body: (setMessage) async {
        setMessage(progressLabel);
        await insertImageUrlsAtCursor(
          controller: controller,
          context: context,
          urls: urls,
          mounted: mounted,
          stripLayoutWhenMultiple: stripLayoutWhenMultiple,
        );
      },
    );
  }
}

/// 표시 영역만: 테두리·배경(공지 화면) 또는 맨본문(바텀시트).
///
/// [QuillEditorConfig]를 매 [build]마다 새로 만들지 않아 키보드·setState 시 본문이 초기화되는 것을 막는다.
class WorkerAnnouncementRichQuillDocumentEditor extends StatefulWidget {
  const WorkerAnnouncementRichQuillDocumentEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    this.placeholder,
    this.padding,
    this.scrollable,
    this.autoFocus,
    this.expands,

    /// [Column]/[Expanded] 안에서 세로 높이를 채울 때 true (무한 높이 제약 방지).
    this.fillParentHeight = false,
    this.decorated = false,
    this.surfaceColor,
    this.borderColor,
  });

  final QuillController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final String? placeholder;
  final EdgeInsetsGeometry? padding;
  final bool? scrollable;
  final bool? autoFocus;
  final bool? expands;
  final bool fillParentHeight;
  final bool decorated;
  final Color? surfaceColor;
  final Color? borderColor;

  @override
  State<WorkerAnnouncementRichQuillDocumentEditor> createState() =>
      _WorkerAnnouncementRichQuillDocumentEditorState();
}

class _WorkerAnnouncementRichQuillDocumentEditorState
    extends State<WorkerAnnouncementRichQuillDocumentEditor>
    with AutomaticKeepAliveClientMixin {
  late QuillEditorConfig _editorConfig;
  var _editorConfigReady = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_editorConfigReady) {
      _rebuildEditorConfig();
      _editorConfigReady = true;
    }
  }

  @override
  void didUpdateWidget(WorkerAnnouncementRichQuillDocumentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeholder != widget.placeholder ||
        oldWidget.padding != widget.padding ||
        oldWidget.scrollable != widget.scrollable ||
        oldWidget.autoFocus != widget.autoFocus ||
        oldWidget.expands != widget.expands ||
        oldWidget.fillParentHeight != widget.fillParentHeight) {
      _rebuildEditorConfig();
    }
  }

  void _rebuildEditorConfig() {
    final useExpands = widget.expands ?? widget.fillParentHeight;
    _editorConfig = WorkerAnnouncementRichQuill.editorConfig(
      placeholder: widget.placeholder,
      padding: widget.padding ??
          EdgeInsets.fromLTRB(
            context.rsi(12),
            context.rsi(8),
            context.rsi(12),
            context.rsi(20),
          ),
      scrollable: widget.scrollable ?? true,
      autoFocus: widget.autoFocus ?? false,
      expands: useExpands,
      customStyles: WorkerAnnouncementRichQuill.quillDefaultStyles(context),
      textSpanBuilder: WorkerAnnouncementRichQuill.safeTextSpanBuilder(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    Widget inner = QuillEditor.basic(
      key: ValueKey<QuillController>(widget.controller),
      controller: widget.controller,
      focusNode: widget.focusNode,
      scrollController: widget.scrollController,
      config: _editorConfig,
    );
    if (widget.fillParentHeight) {
      inner = SizedBox.expand(child: inner);
    }
    if (!widget.decorated) return inner;

    final bg = widget.surfaceColor ?? cs.surfaceContainerLow;
    final border = widget.borderColor ?? cs.outline.withValues(alpha: 0.32);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: inner,
      ),
    );
  }
}

enum WorkerAnnouncementRichQuillToolbarVariant {
  /// 공지 작성 화면 하단 고정 줄(그림자, 업로드 문구 줄).
  bottomSheetBar,

  /// 바텀시트 등 — 포커스 시 인라인 툴바.
  inlineScrolledBar,
}

/// [WorkerAnnouncementRichQuill.toolbarConfig]와 동일 규격의 실제 위젯.
///
/// [uploading] 등으로 부모가 rebuild돼도 [QuillSimpleToolbar] 설정 객체는 유지된다.
class WorkerAnnouncementRichQuillToolbar extends StatefulWidget {
  const WorkerAnnouncementRichQuillToolbar({
    super.key,
    required this.controller,
    required this.variant,
    required this.toolbarConfig,
    required this.uploading,
    this.leadingToolbarWidget,
    this.uploadHintText,
  });

  final QuillController controller;
  final WorkerAnnouncementRichQuillToolbarVariant variant;
  final QuillSimpleToolbarConfig toolbarConfig;
  final bool uploading;
  final Widget? leadingToolbarWidget;

  /// [variant]==[WorkerAnnouncementRichQuillToolbarVariant.bottomSheetBar]일 때 업로드 중 안내 문구.
  final String? uploadHintText;

  @override
  State<WorkerAnnouncementRichQuillToolbar> createState() =>
      _WorkerAnnouncementRichQuillToolbarState();
}

class _WorkerAnnouncementRichQuillToolbarState
    extends State<WorkerAnnouncementRichQuillToolbar> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget bottomBarToolbarRow() {
      return SizedBox(
        height: context.rs(52),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.leadingToolbarWidget != null)
              widget.leadingToolbarWidget!,
            if (widget.leadingToolbarWidget != null)
              VerticalDivider(
                width: 1,
                color: cs.outlineVariant.withValues(alpha: 0.65),
              ),
            Expanded(
              child: QuillSimpleToolbar(
                key: ValueKey<QuillController>(widget.controller),
                controller: widget.controller,
                config: widget.toolbarConfig,
              ),
            ),
          ],
        ),
      );
    }

    switch (widget.variant) {
      case WorkerAnnouncementRichQuillToolbarVariant.bottomSheetBar:
        return Material(
          color: cs.surface,
          elevation: 3,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.uploading)
                  Skeletonizer(
                    enabled: true,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.rsi(16),
                        context.rsi(8),
                        context.rsi(16),
                        0,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.image_outlined,
                              size: context.rs(18), color: cs.primary),
                          SizedBox(width: context.rsi(12)),
                          Expanded(
                            child: Text(
                              widget.uploadHintText ?? '이미지 선택 중…',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                bottomBarToolbarRow(),
              ],
            ),
          ),
        );
      case WorkerAnnouncementRichQuillToolbarVariant.inlineScrolledBar:
        final outerH = context.rs(widget.uploading ? 54 : 52);
        return SizedBox(
          height: outerH,
          child: Material(
            color: cs.surfaceContainerLow,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: cs.outline.withValues(alpha: 0.28),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                if (widget.uploading) SizedBox(height: context.rsi(4)),
                // 가로 SingleChildScrollView로 감싸면 스크롤 축에 maxWidth=∞가 들어가
                // QuillSimpleToolbar 내부 Row(Expanded 정렬 버튼 등)와 충돌한다.
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.rsi(2)),
                    child: QuillSimpleToolbar(
                      key: ValueKey<QuillController>(widget.controller),
                      controller: widget.controller,
                      config: widget.toolbarConfig,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}
