import 'dart:io';

import 'package:flutter/material.dart';
import 'package:w0001/theme/app_segmented_button.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/util/funtions.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

enum PlaceImageTabType { site, drawing, estimate }

enum PlaceImageSourceType { camera, gallery, pdfFile, excelFile }

class PlaceDraftImageItem {
  const PlaceDraftImageItem({
    required this.source,
    required this.virtualUrl,
    this.localPath,
    this.memo,
  });

  final PlaceImageSourceType source;
  final String virtualUrl;
  final String? localPath;

  /// 등록 시 `POST /place-photos`의 `memo`로 전달(비어 있으면 생략).
  final String? memo;

  PlaceDraftImageItem copyWith({
    PlaceImageSourceType? source,
    String? virtualUrl,
    String? localPath,
    String? memo,
  }) =>
      PlaceDraftImageItem(
        source: source ?? this.source,
        virtualUrl: virtualUrl ?? this.virtualUrl,
        localPath: localPath ?? this.localPath,
        memo: memo ?? this.memo,
      );
}

class PlaceImageAttachSheet extends StatelessWidget {
  const PlaceImageAttachSheet({
    super.key,
    required this.titleController,
    required this.selectedType,
    required this.selectedDate,
    required this.draftImages,
    required this.onTypeChanged,
    required this.onPickDate,
    required this.onPickCamera,
    required this.onPickGallery,
    this.onPickDrawingPdf,
    this.onPickEstimateExcel,
    required this.onRemoveDraft,
    required this.onDraftMemoChanged,
    required this.onSubmit,
    required this.isPickingImages,
    this.isSubmitting = false,
    this.showEstimateSegment = false,
  });

  final TextEditingController titleController;
  final PlaceImageTabType selectedType;
  final DateTime selectedDate;
  final List<PlaceDraftImageItem> draftImages;
  final ValueChanged<PlaceImageTabType> onTypeChanged;
  final VoidCallback onPickDate;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;

  /// 도면사진 탭에서만 버튼 노출.
  final VoidCallback? onPickDrawingPdf;

  /// 견적서 탭에서만 버튼 노출.
  final VoidCallback? onPickEstimateExcel;

  final ValueChanged<int> onRemoveDraft;
  final void Function(int index, String memo) onDraftMemoChanged;
  final Future<void> Function() onSubmit;
  final bool isPickingImages;

  /// 서버 업로드·등록 중일 때 **등록** 버튼 비활성 등에 사용.
  final bool isSubmitting;

  /// 관리자만 견적서 탭 노출 (`photo_type` `estimate`).
  final bool showEstimateSegment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final formControlHeight = context.rs(45);
    final formControlShape = AppSegmentedButton.segmentShape;
    final actionTextStyle = tt.labelLarge?.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: ResponsiveLayout.symmetric(context, horizontal: 4, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: ResponsiveLayout.symmetric(context, horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.rs(10)),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '파일 첨부',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                rsV(context, 2),
                Text(
                  _attachHint(selectedType),
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          rsV(context, 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<PlaceImageTabType>(
              segments: [
                ButtonSegment<PlaceImageTabType>(
                  value: PlaceImageTabType.site,
                  label: const Text('현장사진'),
                  icon: Icon(Icons.home_repair_service_outlined, size: context.rsi(20)),
                ),
                ButtonSegment<PlaceImageTabType>(
                  value: PlaceImageTabType.drawing,
                  label: const Text('도면사진'),
                  icon: Icon(Icons.architecture_outlined, size: context.rsi(20)),
                ),
                if (showEstimateSegment)
                  ButtonSegment<PlaceImageTabType>(
                    value: PlaceImageTabType.estimate,
                    label: const Text('견적서'),
                    icon: Icon(Icons.request_quote_outlined, size: context.rsi(20)),
                  ),
              ],
              selected: {selectedType},
              showSelectedIcon: false,
              style: AppSegmentedButton.styleFrom(
                minimumSize: Size.fromHeight(formControlHeight),
                padding: ResponsiveLayout.symmetric(context, horizontal: 10, vertical: 8),
                textStyle: actionTextStyle,
              ),
              onSelectionChanged: (next) {
                if (next.isEmpty) return;
                onTypeChanged(next.first);
              },
            ),
          ),
          rsV(context, 10),
          OutlinedButton.icon(
            onPressed: onPickDate,
            icon: const Icon(Icons.event),
            label: Text(formatDateTimeWeekDayToString(selectedDate)),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, formControlHeight),
              shape: formControlShape,
              padding: ResponsiveLayout.symmetric(context, horizontal: 12, vertical: 8),
              textStyle: actionTextStyle,
            ),
          ),
          rsV(context, 8),
          AddTextField(
            tController: titleController,
            labelText: '작업명 (예: 주방 설비 작업)',
            isPrice: false,
            readOnly: false,
            keyboardType: TextInputType.text,
            witdh: double.infinity,
            height: formControlHeight,
          ),
          rsV(context, 4),
          ..._pickActions(
            context: context,
            selectedType: selectedType,
            isPickingImages: isPickingImages,
            onPickCamera: onPickCamera,
            onPickGallery: onPickGallery,
            onPickDrawingPdf: onPickDrawingPdf,
            onPickEstimateExcel: onPickEstimateExcel,
          ),
          if (isPickingImages)
            Skeletonizer(
              enabled: true,
              child: Padding(
                padding: ResponsiveLayout.only(context, top: 8),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty_rounded,
                        size: context.rsi(16), color: cs.primary),
                    rsH(context, 8),
                    Text(
                      '파일 선택 중…',
                      style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          rsV(context, 8),
          Container(
            width: double.infinity,
            padding: ResponsiveLayout.all(context, 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(context.rs(10)),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: draftImages.isEmpty
                ? Text(
                    _emptyDraftHint(selectedType),
                    style: tt.bodyMedium?.copyWith(color: Colors.black54),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '선택된 항목 ${draftImages.length}건 · 각 줄에 메모를 적을 수 있습니다.',
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      rsV(context, 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: draftImages.length,
                        separatorBuilder: (_, __) => rsV(context, 10),
                        itemBuilder: (_, i) {
                          final item = draftImages[i];
                          return _DraftPhotoMemoRow(
                            item: item,
                            onRemove: () => onRemoveDraft(i),
                            onMemoChanged: (t) => onDraftMemoChanged(i, t),
                          );
                        },
                      ),
                    ],
                  ),
          ),
          rsV(context, 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: draftImages.isEmpty || isSubmitting
                  ? null
                  : () async {
                      await onSubmit();
                    },
              icon: Skeletonizer(
                enabled: isSubmitting,
                child: const Icon(Icons.upload_file_outlined),
              ),
              label: Text(isSubmitting ? '등록 중…' : '등록'),
              style: FilledButton.styleFrom(
                minimumSize: Size(double.infinity, formControlHeight),
                shape: formControlShape,
                padding: ResponsiveLayout.symmetric(context, horizontal: 12, vertical: 8),
                textStyle: actionTextStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftPhotoMemoRow extends StatefulWidget {
  const _DraftPhotoMemoRow({
    required this.item,
    required this.onRemove,
    required this.onMemoChanged,
  });

  final PlaceDraftImageItem item;
  final VoidCallback onRemove;
  final ValueChanged<String> onMemoChanged;

  @override
  State<_DraftPhotoMemoRow> createState() => _DraftPhotoMemoRowState();
}

class _DraftPhotoMemoRowState extends State<_DraftPhotoMemoRow> {
  late TextEditingController _memo;

  @override
  void initState() {
    super.initState();
    _memo = TextEditingController(text: widget.item.memo ?? '');
  }

  @override
  void didUpdateWidget(covariant _DraftPhotoMemoRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.virtualUrl != widget.item.virtualUrl) {
      _memo.dispose();
      _memo = TextEditingController(text: widget.item.memo ?? '');
    }
  }

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DraftThumbCard(item: widget.item, onRemove: widget.onRemove),
        rsH(context, 10),
        Expanded(
          child: TextField(
            controller: _memo,
            onChanged: widget.onMemoChanged,
            maxLines: 3,
            minLines: 2,
            maxLength: 800,
            decoration: InputDecoration(
              labelText: '이 장 메모 (선택)',
              hintText: '등록과 함께 저장됩니다.',
              isDense: true,
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

class _DraftThumbCard extends StatelessWidget {
  const _DraftThumbCard({
    required this.item,
    required this.onRemove,
  });

  final PlaceDraftImageItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.source) {
      PlaceImageSourceType.camera => Icons.photo_camera,
      PlaceImageSourceType.gallery => Icons.image_outlined,
      PlaceImageSourceType.pdfFile => Icons.picture_as_pdf_outlined,
      PlaceImageSourceType.excelFile => Icons.table_chart_outlined,
    };
    final showRasterThumb = item.localPath != null &&
        (item.source == PlaceImageSourceType.camera ||
            item.source == PlaceImageSourceType.gallery);
    return SizedBox(
      width: context.rs(92),
      height: context.rs(92),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.rs(10)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(context.rs(10)),
                ),
                child: item.localPath == null
                    ? Icon(icon, color: Colors.grey.shade700, size: context.rsi(26))
                    : showRasterThumb
                        ? Image.file(
                            File(item.localPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Icon(icon, color: Colors.grey.shade700, size: context.rsi(26)),
                          )
                        : Icon(icon, color: Colors.grey.shade700, size: context.rsi(34)),
              ),
            ),
          ),
          Positioned(
            right: context.rs(4),
            top: context.rs(4),
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: Padding(
                  padding: ResponsiveLayout.all(context, 4),
                  child: Icon(Icons.close, size: context.rsi(14), color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachActionButton extends StatelessWidget {
  const _AttachActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isEnabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(context.rs(10)),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: context.rs(82)),
          child: Ink(
            padding: ResponsiveLayout.symmetric(context, horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.rs(10)),
              border: Border.all(
                color: isEnabled
                    ? cs.outline.withValues(alpha: 0.28)
                    : cs.outline.withValues(alpha: 0.16),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isEnabled ? cs.surfaceBright : cs.surface,
                  isEnabled
                      ? cs.surfaceContainerHigh.withValues(alpha: 0.9)
                      : cs.surfaceContainerLowest,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: context.rs(30),
                  height: context.rs(30),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(context.rs(8)),
                    color: isEnabled
                        ? cs.primaryContainer.withValues(alpha: 0.7)
                        : cs.surfaceContainerHighest,
                  ),
                  child: Icon(
                    icon,
                    color:
                        isEnabled ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    size: context.rsi(18),
                  ),
                ),
                rsV(context, 7),
                Text(
                  title,
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isEnabled ? null : cs.onSurfaceVariant,
                  ),
                ),
                rsV(context, 3),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _attachHint(PlaceImageTabType t) {
  switch (t) {
    case PlaceImageTabType.site:
      return '유형·날짜·작업명을 선택한 뒤 촬영 또는 갤러리로 사진을 추가하세요.';
    case PlaceImageTabType.drawing:
      return '촬영·갤러리 또는 PDF로 도면·문서를 추가하세요.';
    case PlaceImageTabType.estimate:
      return '엑셀(.xlsx, .xls)만 추가할 수 있습니다. 날짜·작업명을 확인하세요.';
  }
}

String _emptyDraftHint(PlaceImageTabType t) {
  switch (t) {
    case PlaceImageTabType.site:
      return '첨부된 사진이 없습니다.\n촬영 또는 갤러리로 추가하세요.';
    case PlaceImageTabType.drawing:
      return '첨부된 항목이 없습니다.\n촬영·갤러리·PDF로 추가하세요.';
    case PlaceImageTabType.estimate:
      return '첨부된 엑셀이 없습니다.\n「엑셀 파일 선택」으로 추가하세요.';
  }
}

List<Widget> _pickActions({
  required BuildContext context,
  required PlaceImageTabType selectedType,
  required bool isPickingImages,
  required VoidCallback onPickCamera,
  required VoidCallback onPickGallery,
  required VoidCallback? onPickDrawingPdf,
  required VoidCallback? onPickEstimateExcel,
}) {
  switch (selectedType) {
    case PlaceImageTabType.estimate:
      return [
        SizedBox(
          width: double.infinity,
          child: _AttachActionButton(
            icon: Icons.table_chart_outlined,
            title: '엑셀 파일 선택',
            subtitle: '.xlsx 또는 .xls',
            onTap: isPickingImages ? null : onPickEstimateExcel,
          ),
        ),
      ];
    case PlaceImageTabType.drawing:
      return [
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                child: _AttachActionButton(
                  icon: Icons.photo_camera_outlined,
                  title: '촬영',
                  subtitle: '카메라',
                  onTap: isPickingImages ? null : onPickCamera,
                ),
              ),
              rsH(context, 8),
              Expanded(
                child: _AttachActionButton(
                  icon: Icons.photo_library_outlined,
                  title: '갤러리',
                  subtitle: '사진',
                  onTap: isPickingImages ? null : onPickGallery,
                ),
              ),
              rsH(context, 8),
              Expanded(
                child: _AttachActionButton(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'PDF',
                  subtitle: '파일 찾기',
                  onTap: isPickingImages ? null : onPickDrawingPdf,
                ),
              ),
            ],
          ),
        ),
      ];
    case PlaceImageTabType.site:
      return [
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                child: _AttachActionButton(
                  icon: Icons.photo_camera_outlined,
                  title: '촬영',
                  subtitle: '카메라로 바로 추가',
                  onTap: isPickingImages ? null : onPickCamera,
                ),
              ),
              rsH(context, 8),
              Expanded(
                child: _AttachActionButton(
                  icon: Icons.photo_library_outlined,
                  title: '갤러리',
                  subtitle: '기기 사진에서 선택',
                  onTap: isPickingImages ? null : onPickGallery,
                ),
              ),
            ],
          ),
        ),
      ];
  }
}
