import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/data/model/place_photo_entry.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_document_opener.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 사진 미리보기 + 메모(및 허용 시 이미지 교체) 동시 노출 패널.
Future<bool?> showPlacePhotoMemoImageSheet(
  BuildContext context, {
  required WidgetRef ref,
  required int pid,
  required String photoType,
  required PlacePhotoEntry entry,
  required bool canEditMemoAndReplace,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) => _MemoImagePanelBody(
      ref: ref,
      pid: pid,
      photoType: photoType,
      entry: entry,
      canEdit: canEditMemoAndReplace,
      bottomInset: MediaQuery.viewInsetsOf(ctx).bottom,
    ),
  );
}

class _MemoImagePanelBody extends StatefulWidget {
  const _MemoImagePanelBody({
    required this.ref,
    required this.pid,
    required this.photoType,
    required this.entry,
    required this.canEdit,
    required this.bottomInset,
  });

  final WidgetRef ref;
  final int pid;
  final String photoType;
  final PlacePhotoEntry entry;
  final bool canEdit;
  final double bottomInset;

  @override
  State<_MemoImagePanelBody> createState() => _MemoImagePanelBodyState();
}

class _MemoImagePanelBodyState extends State<_MemoImagePanelBody> {
  late final TextEditingController _memoCtrl;
  bool _busy = false;
  String? _replacePath;

  @override
  void initState() {
    super.initState();
    _memoCtrl = TextEditingController(text: widget.entry.memo?.trim() ?? '');
  }

  @override
  void dispose() {
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReplace(ImageSource src) async {
    final picker = ImagePicker();
    final x = src == ImageSource.camera
        ? await picker.pickImage(source: ImageSource.camera)
        : await picker.pickImage(source: ImageSource.gallery);
    if (!mounted || x == null) return;
    setState(() => _replacePath = x.path.trim());
  }

  Future<void> _save(BuildContext sheetCtx) async {
    final memo = _memoCtrl.text.trim();
    setState(() => _busy = true);
    final err = await widget.ref
        .read(placeDetailProvider(widget.pid).notifier)
        .patchPlacePhoto(
          phid: widget.entry.phid,
          photoType: widget.photoType,
          memo: memo,
          replacementLocalPath: _replacePath,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!sheetCtx.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    // 성공 플래그를 전달하여 부모 화면에서도 업데이트하도록 함
    Navigator.of(sheetCtx).pop(true);
  }

  bool get _hasHttpImg =>
      widget.entry.displayUrl.startsWith('http://') ||
      widget.entry.displayUrl.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final maxH = h * 0.92;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canEdit = widget.canEdit && widget.entry.phid > 0;
    final me = widget.ref.watch(authSessionProvider).maybeWhen(
          data: (u) => u,
          orElse: () => null,
        );
    final docTools = me?.canViewPlacePhotoDocuments(widget.photoType) == true &&
        widget.entry.canFetchOriginalViaApi;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomInset),
      child: SizedBox(
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: ResponsiveLayout.only(context, left: 8, top: 2, right: 4),
              child: Row(
                children: [
                  Text(
                    canEdit ? '사진 · 메모' : '사진 · 메모 보기',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  if (docTools)
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => openPlacePhotoOriginalDocument(
                                context,
                                entry: widget.entry,
                              ),
                      icon: Icon(Icons.description_outlined, size: context.rsi(18)),
                      label: const Text('PDF·엑셀'),
                    ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: ResponsiveLayout.symmetric(context, horizontal: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(context.rs(14)),
                  child: InteractiveViewer(
                    minScale: 0.82,
                    maxScale: 3.25,
                    child: _replacePath != null
                        ? Image.file(
                            File(_replacePath!),
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            height: double.infinity,
                            width: double.infinity,
                          )
                        : _hasHttpImg
                            ? Image.network(
                                widget.entry.displayUrl,
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                                loadingBuilder: (c, child, prog) {
                                  if (prog == null) return child;
                                  return Skeletonizer(
                                    enabled: true,
                                    child: ColoredBox(
                                      color: cs.surfaceContainerHighest,
                                      child: Center(
                                        child: Text(
                                          '이미지',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Icon(
                                    Icons.broken_image_outlined,
                                    color: cs.outline),
                              )
                            : Center(
                                child: Icon(Icons.image_not_supported_outlined,
                                    color: cs.outline, size: context.rsi(48)),
                              ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                padding: ResponsiveLayout.only(context, left: 16, top: 8, right: 16, bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _memoCtrl,
                      enabled: canEdit && !_busy,
                      maxLines: 6,
                      minLines: 3,
                      maxLength: 800,
                      decoration: InputDecoration(
                        labelText: '현장 메모',
                        hintText: canEdit ? '사진과 함께 남길 내용을 입력하세요.' : '',
                        filled: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (canEdit) ...[
                      rsV(context, 10),
                      if (_replacePath != null)
                        Padding(
                          padding: ResponsiveLayout.only(context, bottom: 8),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _replacePath = null),
                              child: const Text('교체 취소'),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _pickReplace(ImageSource.gallery),
                              icon: Icon(Icons.photo_library_outlined,
                                  size: context.rsi(18)),
                              label: const Text('갤러리에서 교체'),
                            ),
                          ),
                          rsH(context, 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _pickReplace(ImageSource.camera),
                              icon: Icon(Icons.photo_camera_outlined,
                                  size: context.rsi(18)),
                              label: const Text('촬영으로 교체'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    rsV(context, 14),
                    if (canEdit)
                      FilledButton(
                        onPressed: _busy ? null : () => _save(context),
                        child: Skeletonizer(
                          enabled: _busy,
                          child: const Text('저장'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
