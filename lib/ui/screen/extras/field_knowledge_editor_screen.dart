import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:w0001/data/model/field_knowledge_models.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/presentation/viewmodel/field_knowledge_providers.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_rich_quill.dart';
import 'package:w0001/ui/screen/extras/hardware_dictionary_style.dart';
import 'package:w0001/ui/screen/extras/widgets/construction_examples_editor.dart';
import 'package:w0001/ui/widget/app_text_field.dart';
import 'package:w0001/util/image_attachment/upload_image_remote.dart';
import 'package:w0001/util/image_attachment/image_upload_result.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 현장 지식 항목 편집 화면 (생성/수정)
class FieldKnowledgeEditorScreen extends ConsumerStatefulWidget {
  const FieldKnowledgeEditorScreen({
    super.key,
    required this.type,
    this.existingEntry,
    this.initialHardwareKind,
  });

  final KnowledgeEntryType type;
  final KnowledgeEntry? existingEntry;
  final HardwareDictionaryKind? initialHardwareKind;

  @override
  ConsumerState<FieldKnowledgeEditorScreen> createState() =>
      _FieldKnowledgeEditorScreenState();
}

class _FieldKnowledgeEditorScreenState
    extends ConsumerState<FieldKnowledgeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagController;
  late bool _isActive;
  final List<String> _categories = [];
  late HardwareDictionaryKind _hardwareKind;
  final List<String> _tags = [];
  final List<String> _imageUrls = [];
  final List<ConstructionExample> _bestExamples = [];
  final List<ConstructionExample> _worstExamples = [];
  bool _isSaving = false;
  bool _isUploadingImage = false;
  final ImagePicker _imagePicker = ImagePicker();

  // Quill 에디터 (공정 가이드용)
  late quill.QuillController _quillController;
  late FocusNode _quillFocusNode;

  String get _editorTitle {
    if (widget.type == KnowledgeEntryType.material) {
      return _hardwareKind.label;
    }
    return widget.type.displayName;
  }

  bool get _isHardwareEditor => widget.type == KnowledgeEntryType.material;

  bool get _isToolEditor =>
      _isHardwareEditor && _hardwareKind == HardwareDictionaryKind.tool;

  @override
  void initState() {
    super.initState();
    final entry = widget.existingEntry;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _contentController = TextEditingController(text: entry?.content ?? '');
    _tagController = TextEditingController();
    _isActive = entry?.isActive ?? true;
    _quillFocusNode = FocusNode();

    // Quill 초기화 (공정 가이드)
    if (widget.type == KnowledgeEntryType.processGuide &&
        entry != null &&
        entry.isQuillContent) {
      final doc =
          WorkerAnnouncementQuillCodec.decodeToDocument(entry.contentBlocks);
      _quillController = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      _quillController = quill.QuillController.basic();
    }

    if (entry != null) {
      _hardwareKind = widget.type == KnowledgeEntryType.material
          ? KnowledgeCategories.hardwareKindOf(entry.categories)
          : HardwareDictionaryKind.material;
      if (widget.type == KnowledgeEntryType.material) {
        final subcategory = KnowledgeCategories.primarySubcategory(
          entry.categories,
          kind: _hardwareKind,
        );
        if (subcategory != null) _categories.add(subcategory);
      } else {
        _categories.addAll(entry.categories);
      }
      _tags.addAll(entry.tags);
      _imageUrls.addAll(entry.imageUrls);
      final examples = entry.constructionExamples;
      if (examples != null) {
        _bestExamples.addAll(examples.bestExamples);
        _worstExamples.addAll(examples.worstExamples);
      }
    } else {
      _hardwareKind =
          widget.initialHardwareKind ?? HardwareDictionaryKind.material;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _quillController.dispose();
    _quillFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // 카테고리 검증 (철물 사전, 용어사전, 공정 가이드)
    if (widget.type != KnowledgeEntryType.constructionCase &&
        _categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 최소 1개 선택해주세요.')),
      );
      return;
    }

    // 시공사례: 베스트/워스트 중 최소 1개
    if (widget.type == KnowledgeEntryType.constructionCase &&
        _bestExamples.isEmpty &&
        _worstExamples.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('베스트 또는 워스트 사례를 최소 1개 등록해주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    // 공정 가이드는 Quill, 나머지는 Plain Text
    final isProcessGuide = widget.type == KnowledgeEntryType.processGuide;
    final contentType = isProcessGuide ? 'quill' : 'text';
    final List<WorkerAnnouncementBlock> contentBlocks;

    if (isProcessGuide) {
      contentBlocks = [
        WorkerAnnouncementQuillCodec.encodeDocument(_quillController.document)
      ];
    } else {
      contentBlocks = [];
    }

    // content는 플레인텍스트 요약 (검색용)
    String plainContent;
    if (isProcessGuide) {
      final preview =
          WorkerAnnouncementQuillCodec.blocksPlainTextPreview(contentBlocks);
      plainContent = preview.length > 500 ? preview.substring(0, 500) : preview;
    } else {
      plainContent = _contentController.text.trim();
    }

    final categories = widget.type == KnowledgeEntryType.material
        ? KnowledgeCategories.composeHardwareCategories(
            kind: _hardwareKind,
            subcategories: _categories,
          )
        : List<String>.from(_categories);

    final entry = KnowledgeEntry(
      id: widget.existingEntry?.id ?? 0,
      type: widget.type,
      title: _titleController.text.trim(),
      content: plainContent,
      isActive: _isActive,
      imageUrls: _imageUrls,
      categories: categories,
      tags: widget.type == KnowledgeEntryType.material &&
              _hardwareKind == HardwareDictionaryKind.tool
          ? const <String>[]
          : _tags,
      contentType: contentType,
      contentBlocks: contentBlocks,
      constructionExamples: widget.type == KnowledgeEntryType.constructionCase
          ? ConstructionExamples(
              bestExamples: List<ConstructionExample>.from(_bestExamples),
              worstExamples: List<ConstructionExample>.from(_worstExamples),
            )
          : null,
    );

    final ok =
        await ref.read(fieldKnowledgeListProvider.notifier).saveEntry(entry);

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingEntry == null ? '항목을 추가했습니다.' : '항목을 수정했습니다.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장하지 못했습니다.')),
      );
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) return;
    if (_tags.contains(tag)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 추가된 태그입니다.')),
      );
      return;
    }

    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  Future<void> _addImage() async {
    // 이미지 선택 (갤러리 또는 카메라)
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이미지 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile == null || !mounted) return;

    setState(() => _isUploadingImage = true);

    try {
      // 이미지 업로드
      final result = await uploadLocalImageFile(
        pickedFile.path,
        category: ImageUploadCategory.placeImage,
      );

      if (!mounted) return;

      setState(() {
        _imageUrls.add(result.displayUrl);
        _isUploadingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 추가했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 업로드 실패: $e')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() => _imageUrls.removeAt(index));
  }

  /// Quill 에디터에서 이미지 선택 (공정 가이드용)
  Future<String?> _pickImageForQuill(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('사진 촬영'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('동영상'),
              subtitle: const Text('추후 추가 예정'),
              enabled: false,
              onTap: null,
            ),
          ],
        ),
      ),
    );

    if (source == null) return null;

    final pickedFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile == null || !mounted) return null;

    try {
      // 이미지 업로드
      final result = await uploadLocalImageFile(
        pickedFile.path,
        category: ImageUploadCategory.placeImage,
      );

      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 삽입했습니다.')),
      );

      return result.displayUrl;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 업로드 실패: $e')),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingEntry == null
              ? '${_editorTitle} 추가'
              : '${_editorTitle} 수정',
        ),
        actions: [
          if (_isSaving)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.rsi(16)),
              child: const AppLoadingIndicator(),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('저장'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.rsi(16),
            context.rsi(12),
            context.rsi(16),
            MediaQuery.paddingOf(context).bottom + context.rsi(32),
          ),
          children: [
            // 제목
            AppTextFormField(
              controller: _titleController,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: '제목 *',
                hintText: '예: 플렉스 거실장',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '제목을 입력해 주세요.' : null,
            ),
            SizedBox(height: context.rsi(16)),

            // 본문 (공정 가이드는 Quill, 나머지는 TextField)
            if (widget.type == KnowledgeEntryType.processGuide) ...[
              // Quill 에디터 (공정 가이드)
              Text(
                '작업 가이드 내용 *',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              SizedBox(height: context.rsi(8)),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    quill.QuillSimpleToolbar(
                      controller: _quillController,
                      config: WorkerAnnouncementRichQuill.toolbarConfig(
                        onRequestPickImage: _pickImageForQuill,
                        afterToolbarButtonPressed: () {
                          _quillFocusNode.requestFocus();
                        },
                      ),
                    ),
                    Container(
                      height: context.rsi(400),
                      padding: EdgeInsets.all(context.rsi(12)),
                      child: quill.QuillEditor(
                        controller: _quillController,
                        focusNode: _quillFocusNode,
                        scrollController: ScrollController(),
                        config: WorkerAnnouncementRichQuill.editorConfig(
                          placeholder: '작업 순서, 주의사항 등을 입력하세요...',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // TextField (일반 텍스트)
              AppTextFormField(
                controller: _contentController,
                minLines: 5,
                maxLines: 15,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: '내용 *',
                  hintText: '특징, 주의사항, 작업 팁 등을 입력해 주세요.',
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? '내용을 입력해 주세요.'
                    : null,
              ),
            ],
            SizedBox(height: context.rsi(16)),

            // 시공사례: 베스트/워스트
            if (widget.type == KnowledgeEntryType.constructionCase) ...[
              ConstructionExamplesEditor(
                bestExamples: _bestExamples,
                worstExamples: _worstExamples,
                onChanged: ({best, worst}) {
                  setState(() {
                    if (best != null) {
                      _bestExamples
                        ..clear()
                        ..addAll(best);
                    }
                    if (worst != null) {
                      _worstExamples
                        ..clear()
                        ..addAll(worst);
                    }
                  });
                },
              ),
              SizedBox(height: context.rsi(16)),
            ],

            // 카테고리 (철물 사전, 용어사전, 공정 가이드)
            if (widget.type != KnowledgeEntryType.constructionCase) ...[
              Text(
                _isHardwareEditor ? '카테고리 *  ·  1개만 선택' : '카테고리 *',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              SizedBox(height: context.rsi(8)),
              if (_isHardwareEditor) ...[
                Row(
                  children: [
                    for (final kind in HardwareDictionaryKind.values) ...[
                      if (kind != HardwareDictionaryKind.values.first)
                        SizedBox(width: context.rsi(8)),
                      Expanded(
                        child: _HardwareKindToggle(
                          kind: kind,
                          selected: _hardwareKind == kind,
                          onTap: () {
                            if (_hardwareKind == kind) return;
                            setState(() {
                              _hardwareKind = kind;
                              _categories.clear();
                              if (kind == HardwareDictionaryKind.tool) {
                                _tags.clear();
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: context.rsi(12)),
              ],
              _CategorySelector(
                availableCategories: _isHardwareEditor
                    ? KnowledgeCategories.forHardwareKind(_hardwareKind)
                    : KnowledgeCategories.forType(widget.type),
                selectedCategories: _categories,
                singleSelect: _isHardwareEditor,
                showIcons: _isHardwareEditor,
                onCategoriesChanged: (categories) {
                  setState(() {
                    _categories
                      ..clear()
                      ..addAll(categories);
                  });
                },
              ),
              SizedBox(height: context.rsi(16)),
            ],

            // 이미지 (철물 사전만, 공정 가이드는 Quill에서 처리)
            if (widget.type == KnowledgeEntryType.material) ...[
              Text(
                '이미지',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              SizedBox(height: context.rsi(8)),
              if (_isUploadingImage)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        HammerLoadingIndicator(size: 30),
                        SizedBox(height: 8),
                        Text('이미지 업로드 중...'),
                      ],
                    ),
                  ),
                )
              else if (_imageUrls.isEmpty)
                OutlinedButton.icon(
                  onPressed: _addImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('이미지 추가'),
                )
              else
                _ImageList(
                  imageUrls: _imageUrls,
                  onRemove: _removeImage,
                  onAdd: _addImage,
                ),
              SizedBox(height: context.rsi(16)),
            ],

            // 태그 (공구는 사용하지 않음)
            if (!_isToolEditor) ...[
              Text(
                '태그',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              SizedBox(height: context.rsi(8)),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _tagController,
                      decoration: const InputDecoration(
                        hintText: '태그 입력 (예: 목재, 친환경)',
                      ),
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                  SizedBox(width: context.rsi(8)),
                  IconButton(
                    onPressed: _addTag,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              if (_tags.isNotEmpty) ...[
                SizedBox(height: context.rsi(10)),
                Wrap(
                  spacing: context.rsi(8),
                  runSpacing: context.rsi(8),
                  children: _tags.map((tag) {
                    return Chip(
                      label: Text('#$tag'),
                      onDeleted: () => _removeTag(tag),
                      deleteIcon: const Icon(Icons.close_rounded),
                    );
                  }).toList(),
                ),
              ],
              SizedBox(height: context.rsi(16)),
            ],

            // 활성 상태
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              title: const Text('활성화'),
              subtitle: Text(
                _isActive ? '목록에 표시됩니다.' : '비활성 상태 (관리자만 확인 가능)',
              ),
              onChanged: (value) => setState(() => _isActive = value),
            ),
            SizedBox(height: context.rsi(24)),

            // 삭제 버튼 (수정 모드)
            if (widget.existingEntry != null)
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _confirmDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('삭제'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('항목 삭제'),
        content: Text('「${_titleController.text}」을(를) 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);

    final ok = await ref
        .read(fieldKnowledgeListProvider.notifier)
        .deleteEntry(widget.existingEntry!.id);

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('항목을 삭제했습니다.')),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제하지 못했습니다.')),
      );
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 카테고리 선택기
// ────────────────────────────────────────────────────────────────────────────

class _HardwareKindToggle extends StatelessWidget {
  const _HardwareKindToggle({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final HardwareDictionaryKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = HardwareDictionaryStyle.accentFor(kind);
    return Material(
      color: selected ? accent.withValues(alpha: 0.12) : cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(10),
            vertical: context.rsi(12),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.7)
                  : cs.outlineVariant.withValues(alpha: 0.7),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                HardwareDictionaryStyle.iconForKind(kind),
                color: selected ? accent : cs.onSurfaceVariant,
                size: context.rsi(20),
              ),
              SizedBox(width: context.rsi(8)),
              Expanded(
                child: Text(
                  kind.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: selected ? accent : cs.onSurface,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.availableCategories,
    required this.selectedCategories,
    required this.onCategoriesChanged,
    this.singleSelect = false,
    this.showIcons = false,
  });

  final List<String> availableCategories;
  final List<String> selectedCategories;
  final ValueChanged<List<String>> onCategoriesChanged;
  final bool singleSelect;
  final bool showIcons;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (availableCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: context.rsi(8),
          runSpacing: context.rsi(8),
          children: availableCategories.map((category) {
            final isSelected = selectedCategories.contains(category);
            return ChoiceChip(
              avatar: showIcons
                  ? Icon(
                      HardwareDictionaryStyle.iconForCategory(category),
                      size: 16,
                    )
                  : null,
              label: Text(category),
              selected: isSelected,
              showCheckmark: !showIcons,
              onSelected: (selected) {
                if (singleSelect) {
                  if (selected) {
                    onCategoriesChanged(<String>[category]);
                  }
                  return;
                }
                final newList = List<String>.from(selectedCategories);
                if (selected) {
                  newList.add(category);
                } else {
                  newList.remove(category);
                }
                onCategoriesChanged(newList);
              },
              selectedColor: cs.primaryContainer,
            );
          }).toList(),
        ),
        if (selectedCategories.isEmpty) ...[
          SizedBox(height: context.rsi(8)),
          Text(
            singleSelect ? '카테고리를 1개 선택해주세요.' : '최소 1개 이상의 카테고리를 선택해주세요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.error,
                ),
          ),
        ],
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 이미지 리스트
// ────────────────────────────────────────────────────────────────────────────

class _ImageList extends StatelessWidget {
  const _ImageList({
    required this.imageUrls,
    required this.onRemove,
    required this.onAdd,
  });

  final List<String> imageUrls;
  final void Function(int) onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        SizedBox(
          height: context.rsi(120),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imageUrls.length + 1,
            separatorBuilder: (_, __) => SizedBox(width: context.rsi(8)),
            itemBuilder: (context, index) {
              if (index == imageUrls.length) {
                // 추가 버튼
                return InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: context.rsi(120),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outline, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: context.rsi(32), color: cs.onSurfaceVariant),
                        SizedBox(height: context.rsi(4)),
                        Text(
                          '추가',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // 이미지
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrls[index],
                      width: context.rsi(120),
                      height: context.rsi(120),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: context.rsi(120),
                        height: context.rsi(120),
                        color: cs.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  Positioned(
                    top: context.rsi(4),
                    right: context.rsi(4),
                    child: IconButton(
                      onPressed: () => onRemove(index),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                        foregroundColor: Colors.white,
                        iconSize: context.rsi(18),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
