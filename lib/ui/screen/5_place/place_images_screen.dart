import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_photo_group_model.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_image_attach_sheet.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_photo_gallery_sheet.dart';
import 'package:w0001/util/place_photo/share_place_photo_originals.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';

class PlaceImagesScreen extends ConsumerStatefulWidget {
  final PlaceInfoModel placeInfo;

  const PlaceImagesScreen({super.key, required this.placeInfo});

  @override
  ConsumerState<PlaceImagesScreen> createState() => _PlaceImagesScreenState();
}

class _PlaceImagesScreenState extends ConsumerState<PlaceImagesScreen> {
  final List<PlaceDraftImageItem> _draftImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  PlaceImageTabType _tabType = PlaceImageTabType.site;
  bool _isPickingImages = false;
  bool _scheduledInitialPhotoFetch = false;
  DateTimeRange? _photoFilterRange;

  String get _currentPhotoType =>
      _tabType == PlaceImageTabType.site ? 'site' : 'drawing';

  @override
  Widget build(BuildContext context) {
    final placeInfo = widget.placeInfo;
    final state = ref.watch(placeDetailProvider(placeInfo.pid!));
    final vm = ref.read(placeDetailProvider(placeInfo.pid!).notifier);
    if (!_scheduledInitialPhotoFetch) {
      _scheduledInitialPhotoFetch = true;
      Future.microtask(
        () => vm.fetchPlacePhotoGroups(photoType: _currentPhotoType),
      );
    }
    final grouped = <String, List<PlacePhotoGroupModel>>{};
    for (final g in state.photoGroupList) {
      if (!_matchesPhotoFilter(g.photoDate)) continue;
      grouped.putIfAbsent(g.photoDate, () => []).add(g);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: Text('${placeInfo.pname} 사진관리')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAttachSheet(context, vm),
        child: const Icon(Icons.add_a_photo_outlined),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pickPhotoFilterRange(context);
                    if (picked == null) return;
                    setState(() => _photoFilterRange = picked);
                  },
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(_photoFilterLabel()),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: '날짜 필터 초기화',
                onPressed: _photoFilterRange == null
                    ? null
                    : () => setState(() => _photoFilterRange = null),
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<PlaceImageTabType>(
            segments: const [
              ButtonSegment<PlaceImageTabType>(
                value: PlaceImageTabType.site,
                label: Text('현장사진'),
                icon: Icon(Icons.home_repair_service_outlined),
              ),
              ButtonSegment<PlaceImageTabType>(
                value: PlaceImageTabType.drawing,
                label: Text('도면사진'),
                icon: Icon(Icons.architecture_outlined),
              ),
            ],
            selected: {_tabType},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onSelectionChanged: (next) {
              if (next.isEmpty) return;
              setState(() => _tabType = next.first);
              vm.fetchPlacePhotoGroups(photoType: _currentPhotoType);
            },
          ),
          const SizedBox(height: 10),
          if (sortedDates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('등록된 작업 사진이 없습니다.')),
            )
          else
            ...sortedDates.map(
              (dateKey) => _buildDateSection(
                context,
                dateKey: dateKey,
                groups: grouped[dateKey] ?? const [],
                vm: vm,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openAttachSheet(
    BuildContext context,
    PlaceDetailViewModel vm,
  ) async {
    var selectedType = _tabType;
    var selectedDate = ref.read(placeDetailProvider(widget.placeInfo.pid!)).photoPickedDay;
    var uploadingPhotos = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            6,
            12,
            MediaQuery.of(sheetCtx).viewInsets.bottom + 12,
          ),
          child: SingleChildScrollView(
            child: PlaceImageAttachSheet(
              titleController: vm.photoTitleController,
              selectedType: selectedType,
              selectedDate: selectedDate,
              draftImages: _draftImages,
              onTypeChanged: (next) => setSheetState(() => selectedType = next),
              onPickDate: () async {
                final picked = await _pickDateWithScrollableCalendar(
                  sheetCtx,
                  initialDay: selectedDate,
                );
                if (picked != null) {
                  setSheetState(() => selectedDate = picked);
                }
              },
              onPickCamera: () async {
                await _pickFromCamera();
                if (mounted) setSheetState(() {});
              },
              onPickGallery: () async {
                await _pickFromGallery();
                if (mounted) setSheetState(() {});
              },
              onRemoveDraft: (index) {
                setState(() => _draftImages.removeAt(index));
                setSheetState(() {});
              },
              isPickingImages: _isPickingImages,
              isSubmitting: uploadingPhotos,
              onSubmit: () async {
                final paths = _draftImages
                    .map((e) => e.localPath)
                    .whereType<String>()
                    .where((p) => p.isNotEmpty)
                    .toList();
                if (paths.isEmpty) {
                  if (sheetCtx.mounted) {
                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                      const SnackBar(content: Text('기기에 저장된 이미지 경로가 없습니다.')),
                    );
                  }
                  return;
                }
                final typeKey =
                    selectedType == PlaceImageTabType.site ? 'site' : 'drawing';
                setSheetState(() => uploadingPhotos = true);
                try {
                  vm.setPhotoPickedDay(selectedDate);
                  final err = await vm.addPlacePhotoGroupFromDeviceFiles(
                    photoType: typeKey,
                    photoDate: selectedDate,
                    localPaths: paths,
                  );
                  if (!mounted) return;
                  if (err != null) {
                    if (sheetCtx.mounted) {
                      ScaffoldMessenger.of(sheetCtx).showSnackBar(
                        SnackBar(content: Text(err)),
                      );
                    }
                    return;
                  }
                  setState(() {
                    _draftImages.clear();
                    if (_tabType != selectedType) {
                      _tabType = selectedType;
                    }
                  });
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                } finally {
                  if (sheetCtx.mounted) {
                    setSheetState(() => uploadingPhotos = false);
                  }
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateWithScrollableCalendar(
    BuildContext context, {
    required DateTime initialDay,
  }) async {
    DateTime? pickedDay = DateTime(initialDay.year, initialDay.month, initialDay.day);
    final screenH = MediaQuery.sizeOf(context).height;
    final maxHeight = (screenH * 0.60).clamp(400.0, 520.0).toDouble();
    final calHeight = (screenH * 0.34).clamp(240.0, 310.0).toDouble();
    return showDialog<DateTime>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      '날짜 선택',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ScrollableCalendarWidget(
                    height: calHeight,
                    initialSelectedDay: pickedDay,
                    useSingleDaySelection: true,
                    showViewModeToggle: false,
                    disableDateSelectionHighlight: true,
                    onDayPicked: (d) {
                      setDialogState(() => pickedDay = d);
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: const Text(
                          '취소',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(pickedDay),
                        child: const Text('확인'),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<DateTimeRange?> _pickPhotoFilterRange(BuildContext context) async {
    DateTime? singlePicked = _photoFilterRange?.start;
    DateTime? rangeStart = _photoFilterRange?.start;
    DateTime? rangeEnd = _photoFilterRange?.end ?? _photoFilterRange?.start;
    var useRange = (_photoFilterRange?.start != null &&
        _photoFilterRange?.end != null &&
        !_photoFilterRange!.start.isAtSameMomentAs(_photoFilterRange!.end));

    final screenH = MediaQuery.sizeOf(context).height;
    final maxHeight = (screenH * 0.72).clamp(470.0, 620.0).toDouble();
    final calHeight = (screenH * 0.42).clamp(290.0, 380.0).toDouble();

    return showDialog<DateTimeRange>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '사진 날짜 필터',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('단일'),
                        icon: Icon(Icons.calendar_today_outlined, size: 18),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('범위'),
                        icon: Icon(Icons.date_range_outlined, size: 18),
                      ),
                    ],
                    selected: {useRange},
                    showSelectedIcon: false,
                    onSelectionChanged: (next) {
                      if (next.isEmpty) return;
                      setDialogState(() => useRange = next.first);
                    },
                  ),
                  const SizedBox(height: 10),
                  ScrollableCalendarWidget(
                    height: calHeight,
                    useSingleDaySelection: !useRange,
                    showViewModeToggle: false,
                    showRangeSummarySection: useRange,
                    disableDateSelectionHighlight: true,
                    initialSelectedDay: singlePicked ?? DateTime.now(),
                    initialRangeStart: rangeStart,
                    initialRangeEnd: rangeEnd,
                    onDayPicked: (d) {
                      setDialogState(() => singlePicked = d);
                    },
                    onRangeChanged: useRange
                        ? (s, e) {
                            setDialogState(() {
                              rangeStart = s;
                              rangeEnd = e ?? s;
                            });
                          }
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () {
                          if (useRange) {
                            if (rangeStart == null) {
                              Navigator.of(dialogCtx).pop();
                              return;
                            }
                            final start = rangeStart!;
                            final end = rangeEnd ?? start;
                            final normalized = start.isBefore(end)
                                ? DateTimeRange(start: start, end: end)
                                : DateTimeRange(start: end, end: start);
                            Navigator.of(dialogCtx).pop(normalized);
                            return;
                          }
                          if (singlePicked == null) {
                            Navigator.of(dialogCtx).pop();
                            return;
                          }
                          Navigator.of(dialogCtx).pop(
                            DateTimeRange(start: singlePicked!, end: singlePicked!),
                          );
                        },
                        child: const Text('적용'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _matchesPhotoFilter(String photoDate) {
    final range = _photoFilterRange;
    if (range == null) return true;
    final d = DateTime.tryParse(photoDate);
    if (d == null) return true;
    final day = DateTime(d.year, d.month, d.day);
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    final from = start.isBefore(end) ? start : end;
    final to = start.isBefore(end) ? end : start;
    return !day.isBefore(from) && !day.isAfter(to);
  }

  String _photoFilterLabel() {
    final range = _photoFilterRange;
    if (range == null) return '날짜 선택';
    final s = range.start;
    final e = range.end;
    final start = '${s.year}.${s.month.toString().padLeft(2, '0')}.${s.day.toString().padLeft(2, '0')}';
    final end = '${e.year}.${e.month.toString().padLeft(2, '0')}.${e.day.toString().padLeft(2, '0')}';
    return start == end ? start : '$start ~ $end';
  }

  Widget _buildDateSection(
    BuildContext context, {
    required String dateKey,
    required List<PlacePhotoGroupModel> groups,
    required PlaceDetailViewModel vm,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              dateKey,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          ...groups.map((g) => _buildWorkCard(context, g, vm)),
        ],
      ),
    );
  }

  Widget _buildWorkCard(
    BuildContext context,
    PlacePhotoGroupModel group,
    PlaceDetailViewModel vm,
  ) {
    final firstUrl = group.photoUrls.isNotEmpty ? group.photoUrls.first : '';
    final remain = group.photoUrls.length - 1;
    final thumbRemote = _isHttpUrl(firstUrl);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showPlacePhotoGroupGallerySheet(context, group),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    SizedBox(
                      width: 86,
                      height: 86,
                      child: thumbRemote
                          ? Image.network(
                              firstUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey.shade600,
                                  size: 28,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: Icon(
                                firstUrl.startsWith('local://camera')
                                    ? Icons.photo_camera
                                    : Icons.image_outlined,
                                color: Colors.grey.shade600,
                                size: 28,
                              ),
                            ),
                    ),
                    if (remain > 0)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '+$remain',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${group.photoDate} · 이미지 ${group.photoCount}장',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '사진 공유',
                onPressed:
                    group.photos.any((e) => e.canFetchOriginalViaApi)
                        ? () => sharePlacePhotoOriginalEntries(
                              context,
                              group.photos,
                            )
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('공유 가능한 사진이 없습니다'),
                              ),
                            );
                          },
                icon: Icon(
                  Icons.share_outlined,
                  color:
                      group.photos.any((e) => e.canFetchOriginalViaApi)
                          ? Colors.blueGrey
                          : Colors.grey.shade400,
                ),
              ),
              IconButton(
                tooltip: '작업 삭제',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialogCtx) => deleteDialog(
                    onPressed: () => vm
                        .deletePlacePhotoGroup(
                          group.pgid,
                          photoType: _currentPhotoType,
                        )
                        .then((_) {
                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                        }),
                  ),
                ),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    if (_isPickingImages) return;
    setState(() => _isPickingImages = true);
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.camera);
      if (!mounted || file == null) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final baseName = _extractBaseName(file.path);
      setState(() {
        _draftImages.add(
          PlaceDraftImageItem(
            source: PlaceImageSourceType.camera,
            virtualUrl: 'local://camera_${now}_$baseName',
            localPath: file.path,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라 사진을 불러오지 못했습니다.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingImages = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isPickingImages) return;
    setState(() => _isPickingImages = true);
    try {
      final files = await _imagePicker.pickMultiImage();
      if (!mounted || files.isEmpty) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final nextItems = <PlaceDraftImageItem>[];
      for (int i = 0; i < files.length; i++) {
        final baseName = _extractBaseName(files[i].path);
        nextItems.add(
          PlaceDraftImageItem(
            source: PlaceImageSourceType.gallery,
            virtualUrl: 'local://gallery_${now}_${i}_$baseName',
            localPath: files[i].path,
          ),
        );
      }
      setState(() => _draftImages.addAll(nextItems));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('갤러리 사진을 불러오지 못했습니다.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingImages = false);
      }
    }
  }

  String _extractBaseName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    if (idx < 0 || idx == normalized.length - 1) return 'image.jpg';
    return normalized.substring(idx + 1);
  }

  bool _isHttpUrl(String s) {
    return s.startsWith('http://') || s.startsWith('https://');
  }
}
