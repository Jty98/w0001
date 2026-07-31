import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:w0001/data/model/field_knowledge_models.dart';
import 'package:w0001/theme/app_colors.dart';
import 'package:w0001/ui/widget/app_text_field.dart';
import 'package:w0001/util/image_attachment/image_upload_result.dart';
import 'package:w0001/util/image_attachment/upload_image_remote.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 시공사례 베스트/워스트 예시 편집 블록.
class ConstructionExamplesEditor extends StatelessWidget {
  const ConstructionExamplesEditor({
    super.key,
    required this.bestExamples,
    required this.worstExamples,
    required this.onChanged,
  });

  final List<ConstructionExample> bestExamples;
  final List<ConstructionExample> worstExamples;
  final void Function({
    List<ConstructionExample>? best,
    List<ConstructionExample>? worst,
  }) onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '베스트 / 워스트 사례 *',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: context.rsi(4)),
        Text(
          '좋은 시공과 하자·주의 사례를 각각 등록하세요.',
          style: tt.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        SizedBox(height: context.rsi(12)),
        _ExampleGroup(
          title: '베스트',
          accent: Colors.teal,
          examples: bestExamples,
          emptyHint: '아직 베스트 사례가 없습니다.',
          onAdd: () => _openEditor(
            context,
            type: ConstructionExampleType.best,
          ),
          onEdit: (index) => _openEditor(
            context,
            type: ConstructionExampleType.best,
            existing: bestExamples[index],
            index: index,
          ),
          onRemove: (index) {
            final next = List<ConstructionExample>.from(bestExamples)
              ..removeAt(index);
            onChanged(best: next);
          },
        ),
        SizedBox(height: context.rsi(16)),
        _ExampleGroup(
          title: '워스트',
          accent: Colors.orange.shade800,
          examples: worstExamples,
          emptyHint: '아직 워스트 사례가 없습니다.',
          onAdd: () => _openEditor(
            context,
            type: ConstructionExampleType.worst,
          ),
          onEdit: (index) => _openEditor(
            context,
            type: ConstructionExampleType.worst,
            existing: worstExamples[index],
            index: index,
          ),
          onRemove: (index) {
            final next = List<ConstructionExample>.from(worstExamples)
              ..removeAt(index);
            onChanged(worst: next);
          },
        ),
        if (bestExamples.isEmpty && worstExamples.isEmpty) ...[
          SizedBox(height: context.rsi(8)),
          Text(
            '베스트 또는 워스트 사례를 최소 1개 등록해주세요.',
            style: tt.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    required ConstructionExampleType type,
    ConstructionExample? existing,
    int? index,
  }) async {
    final result = await showModalBottomSheet<ConstructionExample>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ExampleEditSheet(
        type: type,
        existing: existing,
      ),
    );
    if (result == null) return;

    if (type == ConstructionExampleType.best) {
      final next = List<ConstructionExample>.from(bestExamples);
      if (index != null) {
        next[index] = result;
      } else {
        next.add(result);
      }
      onChanged(best: next);
    } else {
      final next = List<ConstructionExample>.from(worstExamples);
      if (index != null) {
        next[index] = result;
      } else {
        next.add(result);
      }
      onChanged(worst: next);
    }
  }
}

class _ExampleGroup extends StatelessWidget {
  const _ExampleGroup({
    required this.title,
    required this.accent,
    required this.examples,
    required this.emptyHint,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });

  final String title;
  final Color accent;
  final List<ConstructionExample> examples;
  final String emptyHint;
  final VoidCallback onAdd;
  final void Function(int index) onEdit;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(context.rsi(12)),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rsi(10),
                  vertical: context.rsi(4),
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$title (${examples.length})',
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('추가'),
              ),
            ],
          ),
          if (examples.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.rsi(12)),
              child: Text(
                emptyHint,
                style: tt.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            )
          else
            ...List.generate(examples.length, (i) {
              final e = examples[i];
              return Padding(
                padding: EdgeInsets.only(top: context.rsi(8)),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onEdit(i),
                    child: Padding(
                      padding: EdgeInsets.all(context.rsi(10)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (e.primaryImageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                e.primaryImageUrl!,
                                width: context.rsi(56),
                                height: context.rsi(56),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _thumbPlaceholder(
                                  context,
                                  accent,
                                ),
                              ),
                            )
                          else
                            _thumbPlaceholder(context, accent),
                          SizedBox(width: context.rsi(10)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (e.tips.isNotEmpty) ...[
                                  SizedBox(height: context.rsi(4)),
                                  Text(
                                    e.tips.take(2).join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.labelSmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '삭제',
                            onPressed: () => onRemove(i),
                            icon: const Icon(Icons.delete_outline),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder(BuildContext context, Color accent) {
    return Container(
      width: context.rsi(56),
      height: context.rsi(56),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image_outlined, color: accent),
    );
  }
}

class _ExampleEditSheet extends StatefulWidget {
  const _ExampleEditSheet({
    required this.type,
    this.existing,
  });

  final ConstructionExampleType type;
  final ConstructionExample? existing;

  @override
  State<_ExampleEditSheet> createState() => _ExampleEditSheetState();
}

class _ExampleEditSheetState extends State<_ExampleEditSheet> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _tipController;
  late List<String> _imageUrls;
  late List<String> _tips;
  bool _uploading = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _tipController = TextEditingController();
    _imageUrls = List<String>.from(e?.imageUrls ?? const []);
    _tips = List<String>.from(e?.tips ?? const []);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _tipController.dispose();
    super.dispose();
  }

  Future<void> _addImage() async {
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

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final result = await uploadLocalImageFile(
        picked.path,
        category: ImageUploadCategory.placeImage,
      );
      if (!mounted) return;
      setState(() {
        _imageUrls.add(result.displayUrl);
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 업로드 실패: $e')),
      );
    }
  }

  void _addTip() {
    final tip = _tipController.text.trim();
    if (tip.isEmpty) return;
    setState(() {
      _tips.add(tip);
      _tipController.clear();
    });
  }

  void _submit() {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설명을 입력해 주세요.')),
      );
      return;
    }
    if (_imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 최소 1장 추가해 주세요.')),
      );
      return;
    }
    Navigator.of(context).pop(
      ConstructionExample(
        imageUrls: _imageUrls,
        description: description,
        tips: _tips,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final isBest = widget.type == ConstructionExampleType.best;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          context.rsi(16),
          context.rsi(12),
          context.rsi(16),
          context.rsi(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  isBest ? '베스트 사례' : '워스트 사례',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: context.rsi(8)),
            Text(
              '이미지 *',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: context.rsi(8)),
            if (_uploading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: const AppLoadingIndicator(),
              )
            else ...[
              Wrap(
                spacing: context.rsi(8),
                runSpacing: context.rsi(8),
                children: [
                  ...List.generate(_imageUrls.length, (i) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            _imageUrls[i],
                            width: context.rsi(88),
                            height: context.rsi(88),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () =>
                                  setState(() => _imageUrls.removeAt(i)),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  OutlinedButton(
                    onPressed: _addImage,
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(context.rsi(88), context.rsi(88)),
                    ),
                    child: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                ],
              ),
            ],
            SizedBox(height: context.rsi(16)),
            AppTextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: isBest ? '왜 좋은 사례인지 *' : '왜 주의해야 하는지 *',
                alignLabelWithHint: true,
              ),
            ),
            SizedBox(height: context.rsi(16)),
            Text(
              isBest ? '작업 팁' : '주의사항',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: context.rsi(8)),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _tipController,
                    decoration: const InputDecoration(hintText: '항목 입력 후 추가'),
                    onSubmitted: (_) => _addTip(),
                  ),
                ),
                IconButton(
                  onPressed: _addTip,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            if (_tips.isNotEmpty) ...[
              SizedBox(height: context.rsi(8)),
              Wrap(
                spacing: context.rsi(8),
                runSpacing: context.rsi(8),
                children: _tips.map((tip) {
                  return Chip(
                    label: Text(tip),
                    onDeleted: () => setState(() => _tips.remove(tip)),
                  );
                }).toList(),
              ),
            ],
            SizedBox(height: context.rsi(20)),
            FilledButton(
              onPressed: _uploading ? null : _submit,
              child: Text(widget.existing == null ? '사례 추가' : '사례 수정'),
            ),
          ],
        ),
      ),
    );
  }
}
