import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/place_photo_entry.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_rich_quill.dart';
import 'package:w0001/ui/widget/keyboard_aware.dart';
import 'package:w0001/ui/widget/place_photo_url_multi_pick_dialog.dart';
import 'package:w0001/util/image_attachment/image_upload_result.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 작업 내용(Quill)가 비어 있는지 — 임베드 이미지가 있으면 false.
bool workInstructionBlocksLookEmpty(List<WorkerAnnouncementBlock> blocks) {
  if (blocks.isEmpty) return true;
  try {
    final doc = WorkerAnnouncementQuillCodec.decodeToDocument(blocks);
    return WorkerAnnouncementQuillCodec.deltaLooksEmpty(doc);
  } catch (_) {
    return false;
  }
}

Future<List<WorkerAnnouncementBlock>?> showPlaceWorkInstructionEditorSheet({
  required BuildContext context,
  required int pid,
  required String placeName,
  required String workerLabel,
  required List<WorkerAnnouncementBlock> initialBlocks,
}) {
  return showModalBottomSheet<List<WorkerAnnouncementBlock>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (ctx) => _PlaceWorkInstructionEditorBody(
      pid: pid,
      placeName: placeName,
      workerLabel: workerLabel,
      initialBlocks: List<WorkerAnnouncementBlock>.from(initialBlocks),
    ),
  );
}

class _PlaceWorkInstructionEditorBody extends ConsumerStatefulWidget {
  const _PlaceWorkInstructionEditorBody({
    required this.pid,
    required this.placeName,
    required this.workerLabel,
    required this.initialBlocks,
  });

  final int pid;
  final String placeName;
  final String workerLabel;
  final List<WorkerAnnouncementBlock> initialBlocks;

  @override
  ConsumerState<_PlaceWorkInstructionEditorBody> createState() =>
      _PlaceWorkInstructionEditorBodyState();
}

class _PlaceWorkInstructionEditorBodyState
    extends ConsumerState<_PlaceWorkInstructionEditorBody>
    with KeyboardScrollIntoViewMixin {
  late final QuillController _quillCtrl;
  final _editorFocus = FocusNode();
  final _quillScroll = ScrollController();
  final _editorBlockKey = GlobalKey();
  final _picker = WorkerAnnouncementRichQuill.picker();
  var _uploading = false;
  late final QuillSimpleToolbarConfig _toolbarConfig;
  double? _sheetHeight;

  @override
  void initState() {
    super.initState();
    _toolbarConfig = WorkerAnnouncementRichQuill.toolbarConfig(
      onRequestPickImage: _onGalleryPickImages,
      afterToolbarButtonPressed: _editorFocus.requestFocus,
    );
    _quillCtrl = QuillController(
      document: WorkerAnnouncementQuillCodec.decodeToDocument(
        widget.initialBlocks,
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _editorFocus.addListener(_onEditorFocusChanged);
  }

  Future<String?> _onGalleryPickImages(BuildContext context) {
    return WorkerAnnouncementRichQuill.galleryPickWorkflow(
      context: context,
      controller: _quillCtrl,
      picker: _picker,
      mounted: () => mounted,
      uploadingGuard: _uploading,
      setUploading: (v) => setState(() => _uploading = v),
      stripLayoutWhenMultiple: true,
      uploadCategory: ImageUploadCategory.placeImage,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sheetHeight ??= MediaQuery.sizeOf(context).height * 0.92;
  }

  @override
  GlobalKey get keyboardScrollTargetKey => _editorBlockKey;

  @override
  void onKeyboardMetricsChanged() {
    if (!_editorFocus.hasFocus) return;
    scheduleKeyboardScrollIntoView();
  }

  void _onEditorFocusChanged() {
    if (!mounted) return;
    if (_editorFocus.hasFocus) {
      scheduleKeyboardScrollIntoView();
    }
  }

  @override
  void dispose() {
    _editorFocus.removeListener(_onEditorFocusChanged);
    _quillCtrl.dispose();
    _editorFocus.dispose();
    _quillScroll.dispose();
    super.dispose();
  }

  Future<void> _pickFromPlaceGallery(String photoType, String label) async {
    if (_uploading || !mounted) return;
    setState(() => _uploading = true);
    try {
      final groups = await ref.read(placeUseCaseProvider).getPlacePhotoGroups(
            widget.pid,
            photoType: photoType,
          );
      final photos = <PlacePhotoEntry>[];
      for (final g in groups) {
        photos.addAll(g.photos);
      }
      if (!mounted) return;
      if (photos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label 사진이 없습니다.')),
        );
        return;
      }
      final urls = await showPlacePhotoUrlMultiPickDialog(
        context,
        photos: photos,
        title: '$label에서 넣기',
      );
      if (!mounted || urls.isEmpty) return;
      await WorkerAnnouncementRichQuill.insertImageUrlsWithProgress(
        context: context,
        controller: _quillCtrl,
        urls: urls,
        mounted: () => mounted,
        progressLabel: '현장 사진 첨부 중…',
      );
      if (mounted) _editorFocus.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진 목록을 불러오지 못했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _save() {
    final encoded =
        WorkerAnnouncementQuillCodec.blocksForApi(_quillCtrl.document);
    final out =
        workInstructionBlocksLookEmpty(encoded) ? <WorkerAnnouncementBlock>[] : encoded;
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final h = _sheetHeight ?? MediaQuery.sizeOf(context).height * 0.92;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: SizedBox(
        height: h,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Padding(
              padding: ResponsiveLayout.only(context, left: 18, top: 4, right: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: ResponsiveLayout.all(context, 10),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(context.rs(14)),
                    ),
                    child: Icon(Icons.assignment_turned_in_outlined,
                        color: cs.primary, size: context.rsi(24)),
                  ),
                  rsH(context, 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '작업 내용',
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        rsV(context, 4),
                        Text(
                          widget.placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        rsV(context, 2),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: context.rsi(16), color: cs.tertiary),
                            rsH(context, 6),
                            Expanded(
                              child: Text(
                                widget.workerLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  rsH(context, 6),
                  FilledButton.icon(
                    onPressed: _uploading ? null : _save,
                    icon: Icon(Icons.check_rounded, size: context.rsi(20)),
                    label: const Text('적용'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: ResponsiveLayout.only(context, left: 16, top: 14, right: 16),
              child: Material(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(context.rs(14)),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: ResponsiveLayout.symmetric(context, horizontal: 10, vertical: 8),
                  child: Wrap(
                    spacing: context.rs(10),
                    runSpacing: context.rs(8),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined,
                          size: context.rsi(18), color: cs.primary),
                      Text(
                        '현장 이미지',
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.architecture_rounded,
                            size: context.rsi(18), color: cs.secondary),
                        label: const Text('도면'),
                        onPressed: _uploading
                            ? null
                            : () => _pickFromPlaceGallery('drawing', '도면'),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.construction_rounded,
                            size: context.rsi(18), color: cs.primary),
                        label: const Text('작업 사진'),
                        onPressed: _uploading
                            ? null
                            : () => _pickFromPlaceGallery('site', '작업'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: ResponsiveLayout.only(context, left: 16, top: 10, right: 16),
              child: Row(
                children: [
                  Text(
                    '텍스트·정렬 · 갤러리 이미지',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: ResponsiveLayout.only(context, left: 16, top: 6, right: 16),
              child: WorkerAnnouncementRichQuillToolbar(
                controller: _quillCtrl,
                variant: WorkerAnnouncementRichQuillToolbarVariant.inlineScrolledBar,
                toolbarConfig: _toolbarConfig,
                uploading: _uploading,
              ),
            ),
            rsV(context, 10),
            Expanded(
              child: Padding(
                padding: ResponsiveLayout.only(context, left: 16, right: 16, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '지시 내용',
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                    rsV(context, 8),
                    Expanded(
                      child: Material(
                        key: _editorBlockKey,
                        color: cs.surfaceContainerLow.withValues(alpha: 0.65),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.rs(14)),
                          side: BorderSide(
                            color: cs.outline.withValues(alpha: 0.38),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: ResponsiveLayout.all(context, 6),
                          child: WorkerAnnouncementRichQuillDocumentEditor(
                            controller: _quillCtrl,
                            focusNode: _editorFocus,
                            scrollController: _quillScroll,
                            decorated: false,
                            fillParentHeight: true,
                            placeholder:
                                '오늘 맡은 공정, 주의점, 자재 등을 적어 주세요.',
                            padding: ResponsiveLayout.only(
                              context,
                              left: 10,
                              top: 10,
                              right: 10,
                              bottom: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: context.rs(8) + bottomInset),
              ],
            ),
            if (_uploading)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(context.rsi(20)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            SizedBox(height: context.rsi(12)),
                            Text(
                              '이미지 처리 중…',
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
