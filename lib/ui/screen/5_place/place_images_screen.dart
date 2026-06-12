import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_photo_group_model.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_document_opener.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_image_attach_sheet.dart';
import 'package:w0001/theme/app_segmented_button.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_photo_group_meta_dialog.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_photo_gallery_sheet.dart';
import 'package:w0001/util/place_photo/place_document_classify.dart';
import 'package:w0001/util/place_photo/share_place_photo_originals.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:w0001/util/responsive_layout.dart';

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
  DateTimeRange? _photoFilterRange;

  String get _currentPhotoType {
    switch (_tabType) {
      case PlaceImageTabType.site:
        return 'site';
      case PlaceImageTabType.drawing:
        return 'drawing';
      case PlaceImageTabType.estimate:
        return 'estimate';
    }
  }

  void _syncTabForWorker(UserRead? me) {
    if (me == null || me.isManagementRole) return;
    if (_tabType != PlaceImageTabType.estimate) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _tabType = PlaceImageTabType.site);
      ref
          .read(placeDetailProvider(widget.placeInfo.pid!).notifier)
          .fetchPlacePhotoGroups(photoType: 'site');
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pid = widget.placeInfo.pid;
      if (pid == null) return;
      ref.read(placeDetailProvider(pid).notifier).fetchPlacePhotoGroups(
            photoType: _currentPhotoType,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final placeInfo = widget.placeInfo;
    final me = ref.watch(authSessionProvider).maybeWhen(
          data: (u) => u,
          orElse: () => null,
        );
    _syncTabForWorker(me);
    final showEstimate = me?.isManagementRole ?? false;
    final state = ref.watch(placeDetailProvider(placeInfo.pid!));
    final vm = ref.read(placeDetailProvider(placeInfo.pid!).notifier);
    final grouped = <String, List<PlacePhotoGroupModel>>{};
    for (final g in state.photoGroupList) {
      if (!_matchesPhotoFilter(g.photoDate)) continue;
      grouped.putIfAbsent(g.photoDate, () => []).add(g);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('${placeInfo.pname} 문서 관리')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAttachSheet(context, vm),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: ResponsiveLayout.only(context, left: 12, top: 10, right: 12, bottom: 18),
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
                    minimumSize: Size(double.infinity, context.rs(42)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.rs(10)),
                    ),
                  ),
                ),
              ),
              rsH(context, 8),
              IconButton.filledTonal(
                tooltip: '날짜 필터 초기화',
                onPressed: _photoFilterRange == null
                    ? null
                    : () => setState(() => _photoFilterRange = null),
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
          ),
          rsV(context, 10),
          SegmentedButton<PlaceImageTabType>(
            segments: [
              ButtonSegment<PlaceImageTabType>(
                value: PlaceImageTabType.site,
                label: Text('현장사진', style: TextStyle(fontSize: context.rsi(11)),),
                icon: const Icon(Icons.home_repair_service_outlined),
              ),
              ButtonSegment<PlaceImageTabType>(
                value: PlaceImageTabType.drawing,
                label: Text('도면사진', style: TextStyle(fontSize: context.rsi(11)),),
                icon: const Icon(Icons.architecture_outlined),
              ),
              if (showEstimate)
                ButtonSegment<PlaceImageTabType>(
                  value: PlaceImageTabType.estimate,
                  label: Text('견적서', style: TextStyle(fontSize: context.rsi(11)),),
                  icon: const Icon(Icons.request_quote_outlined),
                ),
            ],
            selected: {_tabType},
            showSelectedIcon: false,
            style: AppSegmentedButton.styleFrom(),
            onSelectionChanged: (next) {
              if (next.isEmpty) return;
              final tab = next.first;
              final photoType = switch (tab) {
                PlaceImageTabType.site => 'site',
                PlaceImageTabType.drawing => 'drawing',
                PlaceImageTabType.estimate => 'estimate',
              };
              setState(() => _tabType = tab);
              vm.fetchPlacePhotoGroups(photoType: photoType);
            },
          ),
          rsV(context, 10),
          if (sortedDates.isEmpty)
            Padding(
              padding: ResponsiveLayout.symmetric(context, vertical: 32),
              child: Center(
                child: Text(
                  '등록된 문서가 없습니다.',
                  style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            ...sortedDates.map(
              (dateKey) => _buildDateSection(
                context,
                me: me,
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
    final me = ref.read(authSessionProvider).maybeWhen(
          data: (u) => u,
          orElse: () => null,
        );
    final showEstimateSeg = me?.isManagementRole ?? false;
    var selectedType = _tabType;
    if (!showEstimateSeg && selectedType == PlaceImageTabType.estimate) {
      selectedType = PlaceImageTabType.site;
    }
    var selectedDate =
        ref.read(placeDetailProvider(widget.placeInfo.pid!)).photoPickedDay;
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
            context.rs(12),
            context.rs(6),
            context.rs(12),
            MediaQuery.of(sheetCtx).viewInsets.bottom + context.rs(12),
          ),
          child: SingleChildScrollView(
            child: PlaceImageAttachSheet(
              titleController: vm.photoTitleController,
              selectedType: selectedType,
              selectedDate: selectedDate,
              draftImages: _draftImages,
              showEstimateSegment: showEstimateSeg,
              onTypeChanged: (next) {
                setSheetState(() => selectedType = next);
                setState(() => _draftImages.clear());
              },
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
              onPickDrawingPdf: () async {
                await _pickPdfForDrawing();
                if (mounted) setSheetState(() {});
              },
              onPickEstimateExcel: () async {
                await _pickExcelForEstimate();
                if (mounted) setSheetState(() {});
              },
              onRemoveDraft: (index) {
                setState(() => _draftImages.removeAt(index));
                setSheetState(() {});
              },
              onDraftMemoChanged: (index, memo) {
                setState(() {
                  _draftImages[index] =
                      _draftImages[index].copyWith(memo: memo);
                });
                setSheetState(() {});
              },
              isPickingImages: _isPickingImages,
              isSubmitting: uploadingPhotos,
              onSubmit: () async {
                final withPaths = _draftImages
                    .where((e) =>
                        e.localPath != null && e.localPath!.trim().isNotEmpty)
                    .toList();
                final paths =
                    withPaths.map((e) => e.localPath!.trim()).toList();
                final memosPerFile =
                    withPaths.map((e) => e.memo ?? '').toList();
                if (paths.isEmpty) {
                  if (sheetCtx.mounted) {
                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                      const SnackBar(content: Text('첨부할 파일 경로가 없습니다.')),
                    );
                  }
                  return;
                }
                final typeKey = switch (selectedType) {
                  PlaceImageTabType.site => 'site',
                  PlaceImageTabType.drawing => 'drawing',
                  PlaceImageTabType.estimate => 'estimate',
                };
                setSheetState(() => uploadingPhotos = true);
                try {
                  vm.setPhotoPickedDay(selectedDate);
                  final err = await vm.addPlacePhotoGroupFromDeviceFiles(
                    photoType: typeKey,
                    photoDate: selectedDate,
                    localPaths: paths,
                    memosPerFile: memosPerFile,
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
    DateTime? pickedDay =
        DateTime(initialDay.year, initialDay.month, initialDay.day);
    final screenH = MediaQuery.sizeOf(context).height;
    final maxHeight = (screenH * 0.60).clamp(400.0, 520.0).toDouble();
    final calHeight = (screenH * 0.34).clamp(240.0, 310.0).toDouble();
    return showDialog<DateTime>(
      context: context,
      builder: (dialogCtx) {
        final tt = Theme.of(dialogCtx).textTheme;
        return StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: ResponsiveLayout.only(dialogCtx, bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: ResponsiveLayout.symmetric(dialogCtx, vertical: 10),
                    child: Text(
                      '날짜 선택',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
                  rsV(dialogCtx, 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: Text(
                          '취소',
                          style: TextStyle(
                            color: Theme.of(dialogCtx)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(pickedDay),
                        child: Text(
                          '확인',
                          style: TextStyle(
                            color: Theme.of(dialogCtx).colorScheme.primary,
                          ),
                        ),
                      ),
                      rsH(dialogCtx, 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      },
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
              padding: ResponsiveLayout.only(dialogCtx, left: 12, top: 10, right: 12, bottom: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '문서 날짜 필터',
                    style: Theme.of(dialogCtx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  rsV(dialogCtx, 8),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: AppSegmentedButton.styleFrom(),
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
                    onSelectionChanged: (next) {
                      if (next.isEmpty) return;
                      setDialogState(() => useRange = next.first);
                    },
                  ),
                  rsV(dialogCtx, 10),
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
                  rsV(dialogCtx, 6),
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
                            DateTimeRange(
                                start: singlePicked!, end: singlePicked!),
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
    final start =
        DateTime(range.start.year, range.start.month, range.start.day);
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
    final start =
        '${s.year}.${s.month.toString().padLeft(2, '0')}.${s.day.toString().padLeft(2, '0')}';
    final end =
        '${e.year}.${e.month.toString().padLeft(2, '0')}.${e.day.toString().padLeft(2, '0')}';
    return start == end ? start : '$start ~ $end';
  }

  String _formatPhotoDateHeading(String raw) {
    final s = raw.length >= 10 ? raw.substring(0, 10) : raw.trim();
    final d = DateTime.tryParse(s);
    if (d == null) return raw;
    final w = ['월', '화', '수', '목', '금', '토', '일'][d.weekday - 1];
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} ($w)';
  }

  Widget _buildDateSection(
    BuildContext context, {
    required UserRead? me,
    required String dateKey,
    required List<PlacePhotoGroupModel> groups,
    required PlaceDetailViewModel vm,
  }) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: ResponsiveLayout.only(context, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: ResponsiveLayout.only(context, left: 2, bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: context.rsi(20),
                  color: cs.primary,
                ),
                rsH(context, 8),
                Text(
                  '작업일 ${_formatPhotoDateHeading(dateKey)}',
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          ...groups.map((g) => _buildWorkCard(context, me, g, vm)),
        ],
      ),
    );
  }

  /// 관리자·또는 묶음 내 모든 사진이 본인 업로드일 때 묶음 메타 수정 가능.
  bool _canEditPhotoGroupMeta(PlacePhotoGroupModel g, UserRead? me) {
    if (me == null || g.pgid <= 0) return false;
    if (!me.isWorker) return true;
    if (g.photos.isEmpty) return false;
    for (final e in g.photos) {
      if (e.createdByUid == null || e.createdByUid != me.uid) return false;
    }
    return true;
  }

  int _memoFilledCount(PlacePhotoGroupModel g) =>
      g.photos.where((e) => e.hasMemo).length;

  bool _canDeletePhotoGroup(PlacePhotoGroupModel g, UserRead? me) {
    if (me == null) return false;
    if (!me.isWorker) return true;
    if (me.uid.isEmpty) return false;
    if (g.photos.isEmpty) return false;
    for (final e in g.photos) {
      if (e.createdByUid == null || e.createdByUid != me.uid) {
        return false;
      }
    }
    return true;
  }

  /// 작업 카드(리스트) 탭 시 묶음이 PDF만 또는 스프레드시트만이면 갤러리 없이 첫 파일을 바로 연다.
  bool _tryOpenDocumentDirectlyFromWorkList(
    BuildContext context,
    UserRead? me,
    PlacePhotoGroupModel group,
  ) {
    if (me?.canViewPlacePhotoDocuments(_currentPhotoType) != true) return false;
    final photos = group.photos;
    if (photos.isEmpty) return false;
    if (!photos.every((e) => e.canFetchOriginalViaApi)) return false;
    final kinds = photos.map(classifyPlaceDocumentForViewer).toList();
    final allPdf = kinds.every((k) => k == PlaceDocumentKind.pdf);
    final allSheet = kinds.every(
      (k) =>
          k == PlaceDocumentKind.spreadsheetXlsx ||
          k == PlaceDocumentKind.legacyXls,
    );
    if (!allPdf && !allSheet) return false;
    openPlacePhotoOriginalDocument(context, entry: photos.first);
    return true;
  }

  /// 묶음 내 사진 업로더(고유). 이름 없으면 uid, 그것도 없으면 `'-'`.
  List<String> _distinctUploaderLabels(PlacePhotoGroupModel g) {
    final seen = <String>{};
    final out = <String>[];
    for (final e in g.photos) {
      final name = e.authorDisplayName?.trim();
      final uid = e.createdByUid?.trim();
      final label = (name != null && name.isNotEmpty)
          ? name
          : (uid != null && uid.isNotEmpty)
              ? uid
              : '-';
      if (!seen.contains(label)) {
        seen.add(label);
        out.add(label);
      }
    }
    return out;
  }

  String _uploadersSummarySentence(PlacePhotoGroupModel g) {
    final names = _distinctUploaderLabels(g);
    if (names.isEmpty) return '업로더 정보 없음';
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]}, ${names[1]}';
    return '${names[0]}, ${names[1]} 외 ${names.length - 2}명';
  }

  Widget _buildWorkCard(
    BuildContext context,
    UserRead? me,
    PlacePhotoGroupModel group,
    PlaceDetailViewModel vm,
  ) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final firstUrl = group.photoUrls.isNotEmpty ? group.photoUrls.first : '';
    final remain = group.photoUrls.length - 1;
    final thumbRemote = _isHttpUrl(firstUrl);
    final memoCount = _memoFilledCount(group);
    final thumbSize = context.rs(86);
    return Card(
      margin: EdgeInsets.only(bottom: context.rs(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(context.rs(12)),
        onTap: () {
          if (_tryOpenDocumentDirectlyFromWorkList(context, me, group)) return;
          showPlacePhotoGroupGallerySheet(
            context,
            group,
            pid: widget.placeInfo.pid!,
            photoType: _currentPhotoType,
            placeDisplayName: widget.placeInfo.pname,
          );
        },
        child: Padding(
          padding: ResponsiveLayout.all(context, 11),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(context.rs(10)),
                child: Stack(
                  children: [
                    SizedBox(
                      width: thumbSize,
                      height: thumbSize,
                      child: thumbRemote
                          ? Image.network(
                              firstUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey.shade600,
                                  size: context.rsi(28),
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
                                size: context.rsi(28),
                              ),
                            ),
                    ),
                    if (remain > 0)
                      Positioned(
                        right: context.rs(4),
                        bottom: context.rs(4),
                        child: Container(
                          padding: ResponsiveLayout.symmetric(
                            context,
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '+$remain',
                            style: tt.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              rsH(context, 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    rsV(context, 8),
                    Text(
                      [
                        '파일 ${group.photos.length}건',
                        if (memoCount > 0) '메모 $memoCount건',
                      ].join(' · '),
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    rsV(context, 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: ResponsiveLayout.only(context, top: 1),
                          child: Icon(
                            Icons.person_outline_rounded,
                            size: context.rsi(18),
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        rsH(context, 6),
                        Expanded(
                          child: Text(
                            _uploadersSummarySentence(group),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurface,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_canEditPhotoGroupMeta(group, me))
                IconButton(
                  tooltip: '작업명·작업일 수정',
                  icon: Icon(Icons.edit_outlined,
                      color: Colors.blueGrey.shade600),
                  onPressed: () => showPlacePhotoGroupMetaEditDialog(
                    context: context,
                    group: group,
                    onSubmit: ({
                      required String title,
                      required String photoDateIso,
                    }) async {
                      final err = await vm.patchPlacePhotoGroupMeta(
                        pgid: group.pgid,
                        photoType: _currentPhotoType,
                        title: title,
                        photoDate: photoDateIso,
                      );
                      return err;
                    },
                  ),
                ),
              IconButton(
                tooltip: '문서 공유',
                onPressed: group.photos.any((e) => e.canFetchOriginalViaApi)
                    ? () => sharePlacePhotoOriginalEntries(
                          context,
                          group.photos,
                          placeDisplayName: widget.placeInfo.pname,
                          groupTitle: group.title,
                        )
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('공유 가능한 문서가 없습니다'),
                          ),
                        );
                      },
                icon: Icon(
                  Icons.share_outlined,
                  color: group.photos.any((e) => e.canFetchOriginalViaApi)
                      ? Colors.blueGrey
                      : Colors.grey.shade400,
                ),
              ),
              if (_canDeletePhotoGroup(group, me))
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

  Future<void> _pickPdfForDrawing() async {
    if (_isPickingImages) return;
    setState(() => _isPickingImages = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < result.files.length; i++) {
        final path = result.files[i].path;
        if (path == null || path.trim().isEmpty) continue;
        final baseName = _extractBaseName(path);
        setState(() {
          _draftImages.add(
            PlaceDraftImageItem(
              source: PlaceImageSourceType.pdfFile,
              virtualUrl: 'local://pdf_${now}_${i}_$baseName',
              localPath: path,
            ),
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF 파일을 선택하지 못했습니다.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingImages = false);
      }
    }
  }

  Future<void> _pickExcelForEstimate() async {
    if (_isPickingImages) return;
    setState(() => _isPickingImages = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls'],
        allowMultiple: true,
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final tmp = await getTemporaryDirectory();
      for (var i = 0; i < result.files.length; i++) {
        final file = result.files[i];
        String? path = file.path?.trim();
        if (path != null && path.isNotEmpty) {
          final f = File(path);
          if (!await f.exists()) path = null;
        }
        if (path == null || path.isEmpty) {
          final bytes = file.bytes;
          if (bytes == null || bytes.isEmpty) continue;
          final rawName = file.name.trim();
          final lower = rawName.toLowerCase();
          final ext = lower.endsWith('.xlsx')
              ? '.xlsx'
              : (lower.endsWith('.xls') ? '.xls' : '.xlsx');
          final safeBase = rawName.isNotEmpty
              ? (lower.endsWith('.xlsx') || lower.endsWith('.xls')
                  ? rawName
                  : '$rawName$ext')
              : 'estimate_${now}_$i$ext';
          final safe = safeBase.replaceAll(RegExp(r'[/\\]'), '_');
          path = '${tmp.path}/place_upload_${now}_${i}_$safe';
          await File(path).writeAsBytes(bytes, flush: true);
        }
        if (path.isEmpty) continue;
        final baseName = _extractBaseName(path);
        setState(() {
          _draftImages.add(
            PlaceDraftImageItem(
              source: PlaceImageSourceType.excelFile,
              virtualUrl: 'local://excel_${now}_${i}_$baseName',
              localPath: path,
            ),
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('엑셀 파일을 선택하지 못했습니다.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingImages = false);
      }
    }
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
