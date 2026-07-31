import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/place_photo_entry.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_rich_quill.dart';
import 'package:w0001/ui/widget/place_photo_url_multi_pick_dialog.dart';
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

/// 인력 투입 바텀시트 위에 또 바텀시트를 열면 키보드 inset 이 꼬이므로 전체 화면으로 연다.
Future<List<WorkerAnnouncementBlock>?> showPlaceWorkInstructionEditorSheet({
  required BuildContext context,
  required int pid,
  required String placeName,
  required String workerLabel,
  required List<WorkerAnnouncementBlock> initialBlocks,
  String sheetTitle = '작업 내용',
}) {
  return Navigator.of(context, rootNavigator: true)
      .push<List<WorkerAnnouncementBlock>>(
    MaterialPageRoute(
      builder: (ctx) => _PlaceWorkInstructionEditorPage(
        pid: pid,
        placeName: placeName,
        workerLabel: workerLabel,
        sheetTitle: sheetTitle,
        initialBlocks: List<WorkerAnnouncementBlock>.from(initialBlocks),
      ),
    ),
  );
}

class _PlaceWorkInstructionEditorPage extends ConsumerStatefulWidget {
  const _PlaceWorkInstructionEditorPage({
    required this.pid,
    required this.placeName,
    required this.workerLabel,
    required this.sheetTitle,
    required this.initialBlocks,
  });

  final int pid;
  final String placeName;
  final String workerLabel;
  final String sheetTitle;
  final List<WorkerAnnouncementBlock> initialBlocks;

  @override
  ConsumerState<_PlaceWorkInstructionEditorPage> createState() =>
      _PlaceWorkInstructionEditorPageState();
}

class _PlaceWorkInstructionEditorPageState
    extends ConsumerState<_PlaceWorkInstructionEditorPage> {
  late final QuillController _quillCtrl;
  final _editorFocus = FocusNode();
  final _quillScroll = ScrollController();
  final _picker = WorkerAnnouncementRichQuill.picker();
  var _uploading = false;
  late final QuillSimpleToolbarConfig _toolbarConfig;

  @override
  void initState() {
    super.initState();
    _toolbarConfig = WorkerAnnouncementRichQuill.toolbarConfig(
      onRequestPickImage: _onGalleryPickImages,
      afterToolbarButtonPressed: _editorFocus.requestFocus,
    );
    _quillCtrl = WorkerAnnouncementQuillCodec.createEditingController(
      document: WorkerAnnouncementQuillCodec.decodeToDocument(
        widget.initialBlocks,
      ),
    );

    // 포커스 시 커서 위치로 스크롤 (키보드에 가려지지 않도록)
    _editorFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_editorFocus.hasFocus) {
      // 포커스 얻으면 짧은 딜레이 후 스크롤 (키보드 애니메이션 대기)
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted || !_editorFocus.hasFocus) return;
        _scrollToCursor();
      });
    }
  }

  void _scrollToCursor() {
    if (!_quillScroll.hasClients) return;

    // 커서 위치 대략 계산 (Quill selection 기반)
    final selection = _quillCtrl.selection;
    if (!selection.isValid || selection.baseOffset < 0) return;

    // 현재 스크롤 위치 유지하면서 약간만 조정
    final currentOffset = _quillScroll.offset;
    final viewportHeight = _quillScroll.position.viewportDimension;
    final maxScroll = _quillScroll.position.maxScrollExtent;

    // 커서가 하단에 있을 경우를 대비해 스크롤 (대략적인 위치)
    final targetOffset =
        (currentOffset + viewportHeight * 0.3).clamp(0.0, maxScroll);

    _quillScroll.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<String?> _onGalleryPickImages(BuildContext context) async {
    // ✅ 갤러리에서 이미지 선택 시 바로 업로드하지 않고 로컬 경로만 저장
    // 저장할 때 (_save 메서드) 한 번에 업로드됨
    if (_uploading || !mounted) return null;

    try {
      final imgs = await _picker.pickMultiImage(imageQuality: 88);
      if (!mounted) return null;
      if (imgs.isEmpty) return null;

      // 로컬 파일 경로만 추출 (업로드 없음!)
      final localPaths =
          imgs.map((e) => e.path.trim()).where((p) => p.isNotEmpty).toList();

      if (localPaths.isEmpty) return null;

      // 로컬 경로를 Quill 에디터에 직접 삽입
      await WorkerAnnouncementRichQuill.insertImageUrlsAtCursor(
        controller: _quillCtrl,
        context: context,
        urls: localPaths, // 로컬 경로 (서버 업로드 안 함!)
        mounted: () => mounted,
        stripLayoutWhenMultiple: true,
      );

      if (mounted) {
        WorkerAnnouncementRichQuill.scheduleCursorAfterEmbedInsert(_quillCtrl);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 첨부 실패: $e')),
        );
      }
    }

    return null;
  }

  @override
  void dispose() {
    _editorFocus.removeListener(_onFocusChanged);
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
      if (mounted) {
        WorkerAnnouncementRichQuill.scheduleCursorAfterEmbedInsert(_quillCtrl);
        _editorFocus.requestFocus();
      }
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

  Future<void> _save() async {
    if (_uploading) return;

    try {
      // ✅ "적용" 버튼: 이미지 업로드 하지 않고 로컬 경로 그대로 반환
      // 최종 "투입 완료"에서 이미지 업로드 + DB 저장됨
      //
      // ⚠️ blocksForApi는 로컬 이미지가 있으면 에러를 던지므로
      // encodeDocument를 직접 사용하여 로컬 이미지 경로를 그대로 보존
      final block =
          WorkerAnnouncementQuillCodec.encodeDocument(_quillCtrl.document);
      final encoded = [block];
      final out = workInstructionBlocksLookEmpty(encoded)
          ? <WorkerAnnouncementBlock>[]
          : encoded;

      if (!mounted) return;
      Navigator.of(context).pop(out);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  Widget _placeGalleryChips(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerLow,
      child: Padding(
        padding:
            ResponsiveLayout.symmetric(context, horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: context.rs(8),
          runSpacing: context.rs(6),
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
              onPressed:
                  _uploading ? null : () => _pickFromPlaceGallery('site', '작업'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _keyboardAttachedToolbar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      elevation: 6,
      shadowColor: cs.shadow.withValues(alpha: 0.12),
      color: cs.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_uploading)
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.rsi(16),
                context.rsi(6),
                context.rsi(16),
                0,
              ),
              child: Text(
                '이미지를 올리는 중입니다…',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          WorkerAnnouncementRichQuillToolbar(
            controller: _quillCtrl,
            variant: WorkerAnnouncementRichQuillToolbarVariant.bottomSheetBar,
            toolbarConfig: _toolbarConfig,
            uploading: _uploading,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = kb > 0;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final toolbarH = context.rs(52) + (_uploading ? context.rsi(28) : 0);
    // ✅ SingleChildScrollView로 자연스럽게 스크롤되므로 기본 gap만 유지
    final editorBottomGap = toolbarH + (keyboardOpen ? kb : safeBottom);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      // 툴바를 viewInsets 기준으로 직접 올리므로 Scaffold 자동 리사이즈는 끈다.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.sheetTitle,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              '${widget.placeName} · ${widget.workerLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          Padding(
            padding: EdgeInsets.only(right: context.rsi(8)),
            child: FilledButton(
              onPressed: _uploading ? null : _save,
              child: const Text('적용'),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(bottom: editorBottomGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!keyboardOpen) _placeGalleryChips(context),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height -
                          (keyboardOpen ? kb + toolbarH + 100 : 200),
                    ),
                    child: Padding(
                      padding: ResponsiveLayout.only(
                        context,
                        left: 12,
                        right: 12,
                        top: keyboardOpen ? 4 : 8,
                        bottom: 4,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(context.rs(14)),
                          border: Border.all(
                            color: cs.outline.withValues(alpha: 0.38),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(context.rs(14)),
                          child: Padding(
                            padding: ResponsiveLayout.all(context, 6),
                            child: WorkerAnnouncementRichQuillDocumentEditor(
                              controller: _quillCtrl,
                              focusNode: _editorFocus,
                              scrollController: _quillScroll,
                              decorated: false,
                              fillParentHeight: false,
                              placeholder: '오늘 맡은 공정, 주의점, 자재 등을 적어 주세요.',
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
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: kb,
            child: SafeArea(
              top: false,
              bottom: !keyboardOpen,
              child: _keyboardAttachedToolbar(context),
            ),
          ),
          if (_uploading)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(context.rsi(20)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HammerLoadingIndicator(size: 28),
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
        ],
      ),
    );
  }
}
