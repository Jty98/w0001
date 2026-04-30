import 'dart:io';

import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/util/funtions.dart';

enum PlaceImageTabType { site, drawing }

enum PlaceImageSourceType { camera, gallery }

class PlaceDraftImageItem {
  const PlaceDraftImageItem({
    required this.source,
    required this.virtualUrl,
    this.localPath,
  });

  final PlaceImageSourceType source;
  final String virtualUrl;
  final String? localPath;
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
    required this.onRemoveDraft,
    required this.onSubmit,
    required this.isPickingImages,
    this.isSubmitting = false,
  });

  final TextEditingController titleController;
  final PlaceImageTabType selectedType;
  final DateTime selectedDate;
  final List<PlaceDraftImageItem> draftImages;
  final ValueChanged<PlaceImageTabType> onTypeChanged;
  final VoidCallback onPickDate;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final ValueChanged<int> onRemoveDraft;
  final Future<void> Function() onSubmit;
  final bool isPickingImages;
  /// 서버 업로드·등록 중일 때 **등록** 버튼 비활성 등에 사용.
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const formControlHeight = 45.0;
    final formControlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이미지 첨부',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '사진 유형, 날짜, 작업명을 선택한 뒤 이미지를 추가하세요.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<PlaceImageTabType>(
              segments: const [
                ButtonSegment<PlaceImageTabType>(
                  value: PlaceImageTabType.site,
                  label: Text('현장사진'),
                  icon: Icon(Icons.home_repair_service_outlined, size: 20),
                ),
                ButtonSegment<PlaceImageTabType>(
                  value: PlaceImageTabType.drawing,
                  label: Text('도면사진'),
                  icon: Icon(Icons.architecture_outlined, size: 20),
                ),
              ],
              selected: {selectedType},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                minimumSize: const Size.fromHeight(formControlHeight),
                shape: formControlShape,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              onSelectionChanged: (next) {
                if (next.isEmpty) return;
                onTypeChanged(next.first);
              },
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onPickDate,
            icon: const Icon(Icons.event),
            label: Text(formatDateTimeWeekDayToString(selectedDate)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, formControlHeight),
              shape: formControlShape,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          AddTextField(
            tController: titleController,
            labelText: '작업명 (예: 주방 설비 작업)',
            isPrice: false,
            readOnly: false,
            keyboardType: TextInputType.text,
            witdh: double.infinity,
            height: formControlHeight,
          ),
          const SizedBox(height: 4),
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
                const SizedBox(width: 8),
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
          if (isPickingImages)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '이미지 첨부 중...',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: draftImages.isEmpty
                ? const Text(
                    '첨부된 이미지가 없습니다.\n촬영 또는 갤러리 버튼으로 추가하세요.',
                    style: TextStyle(color: Colors.black54),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '선택된 이미지 ${draftImages.length}장',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: draftImages.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => _DraftThumbCard(
                            item: draftImages[i],
                            onRemove: () => onRemoveDraft(i),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: draftImages.isEmpty || isSubmitting
                  ? null
                  : () async {
                      await onSubmit();
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(isSubmitting ? '등록 중…' : '등록'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, formControlHeight),
                shape: formControlShape,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
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
    final icon = item.source == PlaceImageSourceType.camera
        ? Icons.photo_camera
        : Icons.image_outlined;
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: item.localPath == null
                    ? Icon(icon, color: Colors.grey.shade700, size: 26)
                    : Image.file(
                        File(item.localPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(icon, color: Colors.grey.shade700, size: 26),
                      ),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 14, color: Colors.white),
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
    final isEnabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 82),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
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
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isEnabled
                        ? cs.primaryContainer.withValues(alpha: 0.7)
                        : cs.surfaceContainerHighest,
                  ),
                  child: Icon(
                    icon,
                    color: isEnabled ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isEnabled ? null : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
