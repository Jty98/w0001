import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/domain/cost_place_picker_filter.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_providers.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_rich_quill.dart';
import 'package:w0001/ui/widget/place_picker/place_cost_picker_sheet.dart';
import 'package:w0001/theme/app_input_styles.dart';
import 'package:w0001/theme/app_segmented_button.dart';
import 'package:w0001/ui/widget/keyboard_aware.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/app_text_field.dart';

/// 현장에서 공지 작성·수정 시 범위 고정·상단 라벨용.
final class PlaceAnnouncementEditAnchor {
  const PlaceAnnouncementEditAnchor({
    required this.pid,
    required this.displayName,
  });

  final int pid;
  final String displayName;
}

/// [`/dashboard/worker-announcements/edit`] 라우트 [extra] 래핑.
///
/// * [existing] 만 → 수정
/// * 없음 → 신규 (전체·현장 선택 가능)
/// * [placeAnchor]만 → 해당 현장 공지 신규
/// * [existing]+[placeAnchor] → 현장 화면에서 수정 (범위 UI 숨김)
final class AdminWorkerAnnouncementEditExtra {
  const AdminWorkerAnnouncementEditExtra({
    this.existing,
    this.placeAnchor,
  });

  final WorkerAnnouncementRead? existing;
  final PlaceAnnouncementEditAnchor? placeAnchor;
}

/// 관리자: 공지 작성·수정.
class AdminWorkerAnnouncementEditScreen extends ConsumerStatefulWidget {
  const AdminWorkerAnnouncementEditScreen({
    super.key,
    this.existing,
    this.placeAnchor,
  });

  final WorkerAnnouncementRead? existing;
  final PlaceAnnouncementEditAnchor? placeAnchor;

  @override
  ConsumerState<AdminWorkerAnnouncementEditScreen> createState() =>
      _AdminWorkerAnnouncementEditScreenState();
}

class _AdminWorkerAnnouncementEditScreenState
    extends ConsumerState<AdminWorkerAnnouncementEditScreen>
    with KeyboardScrollIntoViewMixin {
  final _titleCtrl = TextEditingController();
  WorkerAnnouncementScope _scope = WorkerAnnouncementScope.global;
  int? _placeId;
  String? _selectedPlaceName;
  var _busy = false;
  var _uploadingImages = false;
  var _loadingEditor = false;
  String? _editorLoadError;

  late QuillController _quillCtrl;
  final _editorFocus = FocusNode();
  final _quillScroll = ScrollController();
  final GlobalKey _editorBlockKey = GlobalKey();

  bool _toolbarVisible = false;
  final ImagePicker _picker = WorkerAnnouncementRichQuill.picker();
  late final QuillSimpleToolbarConfig _toolbarConfig;

  @override
  void initState() {
    super.initState();
    _toolbarConfig = WorkerAnnouncementRichQuill.toolbarConfig(
      onRequestPickImage: _onRequestPickImages,
      afterToolbarButtonPressed: _editorFocus.requestFocus,
    );
    final e = widget.existing;
    final anchor = widget.placeAnchor;

    _quillCtrl = WorkerAnnouncementQuillCodec.createEditingController(
      document: Document(),
    );

    if (e != null) {
      _titleCtrl.text = e.title;
      if (anchor != null) {
        _scope = WorkerAnnouncementScope.place;
        _placeId = anchor.pid;
        _selectedPlaceName = anchor.displayName;
      } else {
        _scope = e.scope;
        _placeId = e.pid;
      }
      if (WorkerAnnouncementQuillCodec.blocksHaveDisplayableBody(e.blocks)) {
        _applyEditorContent(e);
      } else {
        _loadingEditor = true;
        unawaited(_loadEditorContent(e));
      }
    } else {
      _quillCtrl = WorkerAnnouncementQuillCodec.createEditingController(
        document: WorkerAnnouncementQuillCodec.documentForEditing(null),
      );
      if (anchor != null) {
        _scope = WorkerAnnouncementScope.place;
        _placeId = anchor.pid;
        _selectedPlaceName = anchor.displayName;
      }
    }

    _editorFocus.addListener(_onEditorFocusChanged);
    _toolbarVisible = _editorFocus.hasFocus;
  }

  void _applyEditorContent(WorkerAnnouncementRead full) {
    final anchor = widget.placeAnchor;
    _titleCtrl.text = full.title;
    if (anchor != null) {
      _scope = WorkerAnnouncementScope.place;
      _placeId = anchor.pid;
    } else {
      _scope = full.scope;
      _placeId = full.pid;
    }
    _replaceQuillDocument(
      WorkerAnnouncementQuillCodec.documentForEditing(full),
    );
    _loadingEditor = false;
    _editorLoadError = null;
  }

  Future<void> _loadEditorContent(WorkerAnnouncementRead summary) async {
    try {
      final full = await ref
          .read(workerAnnouncementUseCaseProvider)
          .resolveDetail(summary);
      if (!mounted) return;
      _applyEditorContent(full);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingEditor = false;
        _editorLoadError = '$e';
      });
    }
  }

  void _replaceQuillDocument(Document doc) {
    _quillCtrl.dispose();
    _quillCtrl = WorkerAnnouncementQuillCodec.createEditingController(
      document: doc,
    );
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
    final v = _editorFocus.hasFocus;
    if (v != _toolbarVisible) {
      setState(() {
        _toolbarVisible = v;
      });
    }
    if (v) {
      scheduleKeyboardScrollIntoView();
    }
  }

  @override
  void dispose() {
    _editorFocus.removeListener(_onEditorFocusChanged);
    _titleCtrl.dispose();
    _quillCtrl.dispose();
    _editorFocus.dispose();
    _quillScroll.dispose();
    super.dispose();
  }

  bool get _scopeFieldsLocked =>
      widget.placeAnchor != null || widget.existing != null;

  Future<void> _pickPlaceForAnnouncement() async {
    final picked = await showPlaceCostPickerSheet(
      context: context,
      ref: ref,
      filter: CostPlacePickerFilter.all,
      selectedPid: _placeId,
    );
    if (!mounted || picked == null) return;
    final pid = picked.pid;
    if (pid == null || pid <= 0) return;
    setState(() {
      _placeId = pid;
      _selectedPlaceName = picked.pname.trim();
    });
  }

  WorkerAnnouncementScope get _effectiveScope => _scopeFieldsLocked
      ? (widget.existing?.scope ?? WorkerAnnouncementScope.place)
      : _scope;

  int? get _effectivePlaceId {
    if (_scopeFieldsLocked) {
      return widget.placeAnchor?.pid ?? widget.existing?.pid ?? _placeId;
    }
    return _effectiveScope == WorkerAnnouncementScope.place ? _placeId : null;
  }

  Future<String?> _onRequestPickImages(BuildContext context) {
    return WorkerAnnouncementRichQuill.galleryPickWorkflow(
      context: context,
      controller: _quillCtrl,
      picker: _picker,
      mounted: () => mounted,
      uploadingGuard: _busy || _uploadingImages,
      setUploading: (v) => setState(() => _uploadingImages = v),
      stripLayoutWhenMultiple: true,
    );
  }

  Future<void> _save() async {
    if (_loadingEditor) return;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해 주세요.')),
      );
      return;
    }
    if (_effectiveScope == WorkerAnnouncementScope.place &&
        _effectivePlaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현장 공지인 경우 현장을 선택해 주세요.')),
      );
      return;
    }
    if (WorkerAnnouncementQuillCodec.deltaLooksEmpty(_quillCtrl.document)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('본문(텍스트 또는 사진)을 입력해 주세요.')),
      );
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      final hadLocal = WorkerAnnouncementQuillCodec.documentHasLocalImages(
        _quillCtrl.document,
      );
      final doc = await WorkerAnnouncementRichQuill.prepareDocumentForSave(
        context: context,
        doc: _quillCtrl.document,
        mounted: () => mounted,
      );
      if (!mounted) return;
      if (hadLocal) _replaceQuillDocument(doc);

      final body = WorkerAnnouncementWriteBody(
        scope: _effectiveScope,
        pid: _effectivePlaceId,
        title: title,
        blocks: WorkerAnnouncementQuillCodec.blocksForApi(_quillCtrl.document),
      );

      final uc = ref.read(workerAnnouncementUseCaseProvider);
      if (widget.existing == null) {
        await uc.create(body);
      } else {
        await uc.update(widget.existing!.id, body);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장했습니다.')),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final anchor = widget.placeAnchor;
    final showScopeUi = !_scopeFieldsLocked;
    final isNew = widget.existing == null;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          anchor != null
              ? (isNew ? '공지 작성' : '공지 수정')
              : (isNew ? '새 공지' : '공지 수정'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.rsi(16),
                    context.rsi(12),
                    context.rsi(16),
                    context.rsi(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (anchor != null) ...[
                        Text(
                          '「${anchor.displayName}」 공지',
                          textAlign: TextAlign.center,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.35,
                          ),
                        ),
                        SizedBox(height: context.rsi(12)),
                      ],
                      AppTextField(
                        controller: _titleCtrl,
                        style: AppInputStyles.fieldText(context),
                        decoration: const InputDecoration(
                          labelText: '제목',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      if (showScopeUi) ...[
                        SizedBox(height: context.rsi(12)),
                        Text(
                          '공지 범위',
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: context.rsi(6)),
                        SegmentedButton<WorkerAnnouncementScope>(
                          showSelectedIcon: false,
                          style: AppSegmentedButton.styleFrom(),
                          segments: const [
                            ButtonSegment(
                              value: WorkerAnnouncementScope.global,
                              label: Text('전체 공지'),
                            ),
                            ButtonSegment(
                              value: WorkerAnnouncementScope.place,
                              label: Text('현장 공지'),
                            ),
                          ],
                          selected: {_scope},
                          onSelectionChanged: _busy
                              ? null
                              : (next) {
                                  setState(() {
                                    _scope = next.first;
                                    if (_scope ==
                                        WorkerAnnouncementScope.global) {
                                      _placeId = null;
                                      _selectedPlaceName = null;
                                    }
                                  });
                                },
                        ),
                        if (_scope == WorkerAnnouncementScope.place) ...[
                          SizedBox(height: context.rsi(8)),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            title: Text(
                              _selectedPlaceName?.trim().isNotEmpty == true
                                  ? _selectedPlaceName!.trim()
                                  : '현장을 선택하세요',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _busy ? null : _pickPlaceForAnnouncement,
                          ),
                        ],
                      ] else ...[
                        SizedBox(height: context.rsi(12)),
                        Text(
                          '공지 범위',
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: context.rsi(6)),
                        Container(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: context.rsi(12),
                            vertical: context.rsi(10),
                          ),
                          child: Text(
                            _effectiveScope == WorkerAnnouncementScope.global
                                ? '전체 공지 (수정 불가)'
                                : '현장 공지 (수정 불가)',
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.rsi(16),
                    context.rsi(4),
                    context.rsi(16),
                    context.rsi(6),
                  ),
                  child: Text(
                    '내용',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: _editorBlockKey,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.rsi(16),
                        0,
                        context.rsi(16),
                        context.rsi(8),
                      ),
                      child: _loadingEditor
                          ? Skeletonizer(
                              enabled: true,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: cs.outline.withValues(alpha: 0.32),
                                  ),
                                ),
                              ),
                            )
                          : _editorLoadError != null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      '본문을 불러오지 못했습니다.\n$_editorLoadError',
                                      textAlign: TextAlign.center,
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.error,
                                      ),
                                    ),
                                  ),
                                )
                              : WorkerAnnouncementRichQuillDocumentEditor(
                                  controller: _quillCtrl,
                                  focusNode: _editorFocus,
                                  scrollController: _quillScroll,
                                  placeholder: '본문을 입력하세요',
                                  decorated: true,
                                  fillParentHeight: true,
                                ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_toolbarVisible) ...[
            WorkerAnnouncementRichQuillToolbar(
              controller: _quillCtrl,
              variant: WorkerAnnouncementRichQuillToolbarVariant.bottomSheetBar,
              toolbarConfig: _toolbarConfig,
              uploading: _uploadingImages,
              uploadHintText: '이미지 선택 중…',
              leadingToolbarWidget: _AnnouncementFontSizeDropdown(
                controller: _quillCtrl,
                editorFocus: _editorFocus,
                enabled: !_busy && !_uploadingImages,
              ),
            ),
          ],
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rsi(16),
                  vertical: context.rsi(12),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_busy || _uploadingImages || _loadingEditor)
                        ? null
                        : _save,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: context.rsi(16)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Skeletonizer(
                      enabled: _busy,
                      child: Text(
                        '저장',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimary,
                            ),
                      ),
                    ),
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

/// 에디터는 Quill 규격에 맞게 size 값을 `null`(보통)·`small`·`large`·`huge` 만 쓴다.
/// (숫자·기타는 읽을 때 구간만 맞춰 표시 라벨로 쓴다.)
final class _AnnouncementFontSizeDropdown extends StatefulWidget {
  const _AnnouncementFontSizeDropdown({
    required this.controller,
    required this.editorFocus,
    this.enabled = true,
  });

  final QuillController controller;
  final FocusNode editorFocus;
  final bool enabled;

  static String _selectionKey(dynamic raw) {
    if (raw == null) return 'default';
    final s = raw.toString().trim();
    if (s.isEmpty || s == '0' || s == 'normal') return 'default';
    if (s == 'small' || s == 'large' || s == 'huge') return s;
    final d = double.tryParse(s);
    if (d != null) {
      if (d <= 0) return 'default';
      if (d <= 12) return 'small';
      if (d <= 17) return 'default';
      if (d <= 20) return 'large';
      return 'huge';
    }
    return 'default';
  }

  static String _labelForWire(String wire) {
    return switch (wire) {
      'small' => '작게',
      'large' => '크게',
      'huge' => '아주 크게',
      _ => '보통',
    };
  }

  static Attribute? _attributeForWire(String wire) {
    return switch (wire) {
      'default' => Attribute.clone(Attribute.size, null),
      'small' => Attribute.clone(Attribute.size, 'small'),
      'large' => Attribute.clone(Attribute.size, 'large'),
      'huge' => Attribute.clone(Attribute.size, 'huge'),
      _ => Attribute.clone(Attribute.size, null),
    };
  }

  @override
  State<_AnnouncementFontSizeDropdown> createState() =>
      _AnnouncementFontSizeDropdownState();
}

class _AnnouncementFontSizeDropdownState
    extends State<_AnnouncementFontSizeDropdown> {
  /// 메뉴가 뜨기 직전의 선택(포커스가 빠지면 바뀌므로 한 번 고정).
  TextSelection _selectionSnapshot = const TextSelection.collapsed(offset: 0);
  OverlayEntry? _overlayEntry;

  void _onTriggerPointerDown(PointerDownEvent event) {
    _selectionSnapshot = widget.controller.selection;
  }

  void _applyPicked(String picked) {
    final ctrl = widget.controller;
    final attr = _AnnouncementFontSizeDropdown._attributeForWire(picked);

    var sel = _selectionSnapshot;
    if (!sel.isValid) {
      sel = ctrl.selection;
    }

    var start = sel.start;
    var end = sel.end;
    final docLen = ctrl.document.length;

    start = start.clamp(0, docLen);
    end = end.clamp(0, docLen);
    if (end < start) {
      final t = start;
      start = end;
      end = t;
    }

    final len = end - start;
    ctrl.formatText(start, len, attr);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.editorFocus.hasFocus) {
        widget.editorFocus.requestFocus();
      }
    });
  }

  void _showFontSizeMenu(BuildContext context, String currentWire) {
    if (_overlayEntry != null) return;

    final RenderBox button = context.findRenderObject() as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => _FontSizeMenuOverlay(
        buttonPosition: buttonPosition,
        buttonSize: button.size,
        screenHeight: screenHeight,
        currentWire: currentWire,
        onSelected: (value) {
          _applyPicked(value);
          _closeMenu();
        },
        onDismiss: _closeMenu,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeMenu() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onTriggerPointerDown,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final attrs = widget.controller.getSelectionStyle().attributes;
          final sizeAttr = attrs[Attribute.size.key];
          final wire = _AnnouncementFontSizeDropdown._selectionKey(
            sizeAttr?.value,
          );

          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;

          return Padding(
            padding: EdgeInsets.only(
              left: context.rsi(12),
              right: context.rsi(4),
            ),
            child: Center(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: widget.enabled
                      ? () => _showFontSizeMenu(context, wire)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rsi(8),
                      vertical: context.rsi(12),
                    ),
                    child: SizedBox(
                      width: context.rs(120),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _AnnouncementFontSizeDropdown._labelForWire(
                                wire,
                              ),
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelLarge,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 커스텀 오버레이로 메뉴 표시 (포커스 유지)
class _FontSizeMenuOverlay extends StatelessWidget {
  const _FontSizeMenuOverlay({
    required this.buttonPosition,
    required this.buttonSize,
    required this.screenHeight,
    required this.currentWire,
    required this.onSelected,
    required this.onDismiss,
  });

  final Offset buttonPosition;
  final Size buttonSize;
  final double screenHeight;
  final String currentWire;
  final void Function(String) onSelected;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Stack(
      children: [
        // 바깥 영역 탭하면 닫기
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 메뉴를 버튼 바로 위에 표시
        Positioned(
          left: buttonPosition.dx,
          bottom: screenHeight - buttonPosition.dy,
          width: buttonSize.width,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: cs.surfaceContainerHigh,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MenuItem(
                  label: '보통',
                  isSelected: currentWire == 'default',
                  onTap: () => onSelected('default'),
                  textTheme: tt,
                ),
                _MenuItem(
                  label: '작게',
                  isSelected: currentWire == 'small',
                  onTap: () => onSelected('small'),
                  textTheme: tt,
                ),
                _MenuItem(
                  label: '크게',
                  isSelected: currentWire == 'large',
                  onTap: () => onSelected('large'),
                  textTheme: tt,
                ),
                _MenuItem(
                  label: '아주 크게',
                  isSelected: currentWire == 'huge',
                  onTap: () => onSelected('huge'),
                  textTheme: tt,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.textTheme,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: context.rs(48),
        padding: EdgeInsets.symmetric(horizontal: context.rsi(16)),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : null,
          ),
        ),
      ),
    );
  }
}
