import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/place_photo_entry.dart';
import 'package:w0001/data/model/place_photo_group_model.dart';
import 'package:w0001/navigation/app_router.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart';
import 'package:w0001/util/place_photo/place_document_classify.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_document_opener.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_photo_group_meta_dialog.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_photo_memo_image_sheet.dart';
import 'package:w0001/util/place_photo/share_place_photo_originals.dart';
import 'package:w0001/ui/widget/place_network_image.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

String _formatPhotoDateForSheet(String raw) {
  final s = raw.length >= 10 ? raw.substring(0, 10) : raw.trim();
  final d = DateTime.tryParse(s);
  if (d == null) return '업로드일 $raw';
  final w = ['월', '화', '수', '목', '금', '토', '일'][d.weekday - 1];
  return '업로드일 ${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} ($w)';
}

bool _canEditPhotoMemo(PlacePhotoEntry e, UserRead? me) {
  if (e.phid <= 0) return false;
  if (me == null) return false;
  if (!me.isWorker) return true;
  final u = e.createdByUid;
  return u != null && u.isNotEmpty && u == me.uid;
}

bool _canEditGroupMeta(PlacePhotoGroupModel g, UserRead? me) {
  if (me == null || g.pgid <= 0) return false;
  if (!me.isWorker) return true;
  if (g.photos.isEmpty) return false;
  for (final e in g.photos) {
    if (e.createdByUid == null || e.createdByUid != me.uid) return false;
  }
  return true;
}

/// 현장 문서·사진 그룹: 그리드 갤러리 → 확대 시 메모 확인·편집(PDF·엑셀 원본 열기).
Future<void> showPlacePhotoGroupGallerySheet(
  BuildContext context,
  PlacePhotoGroupModel group, {
  required int pid,
  required String photoType,
  required String placeDisplayName,
}) {
  final entries = group.photos;
  if (entries.isEmpty) return Future.value();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetCtx) => _PlacePhotoGallerySheet(
      fallbackGroup: group,
      pid: pid,
      photoType: photoType,
      placeDisplayName: placeDisplayName,
    ),
  );
}

class _PlacePhotoGallerySheet extends ConsumerStatefulWidget {
  const _PlacePhotoGallerySheet({
    required this.fallbackGroup,
    required this.pid,
    required this.photoType,
    required this.placeDisplayName,
  });

  final PlacePhotoGroupModel fallbackGroup;
  final int pid;
  final String photoType;
  final String placeDisplayName;

  @override
  ConsumerState<_PlacePhotoGallerySheet> createState() =>
      _PlacePhotoGallerySheetState();
}

class _PlacePhotoGallerySheetState
    extends ConsumerState<_PlacePhotoGallerySheet> {
  bool _selectionMode = false;
  final Set<int> _selected = <int>{};

  PlacePhotoGroupModel _resolvedGroup() {
    final list = ref.watch(placeDetailProvider(widget.pid)).photoGroupList;
    for (final g in list) {
      if (g.pgid == widget.fallbackGroup.pgid) return g;
    }
    return widget.fallbackGroup;
  }

  List<PlacePhotoEntry> get _entries => _resolvedGroup().photos;

  void _leaveSelection({bool cleared = true}) {
    setState(() {
      _selectionMode = false;
      if (cleared) _selected.clear();
    });
  }

  void _toggleIndex(int i) {
    if (!_selectionMode) return;
    final e = _entries[i];
    if (!e.canFetchOriginalViaApi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연결된 항목만 선택해 공유할 수 있습니다.')),
      );
      return;
    }
    setState(() {
      if (_selected.contains(i)) {
        _selected.remove(i);
      } else {
        _selected.add(i);
      }
    });
  }

  Future<void> _shareSelected(BuildContext sheetCtx) async {
    final list = _selected
        .map((i) => _entries[i])
        .where((e) => e.canFetchOriginalViaApi)
        .toList();
    if (list.isEmpty) return;
    await sharePlacePhotoOriginalEntries(
      sheetCtx,
      list,
      placeDisplayName: widget.placeDisplayName,
      groupTitle: _resolvedGroup().title,
    );
    if (!sheetCtx.mounted) return;
    _leaveSelection();
  }

  @override
  Widget build(BuildContext context) {
    final sheetCtx = context;
    final bottomInset = MediaQuery.viewPaddingOf(sheetCtx).bottom;
    final shareable = _entries.any((e) => e.canFetchOriginalViaApi);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final group = _resolvedGroup();
    final me = ref
        .watch(authSessionProvider)
        .maybeWhen(data: (u) => u, orElse: () => null);

    Future<void> openGroupMetaEdit() async {
      await showPlacePhotoGroupMetaEditDialog(
        context: sheetCtx,
        group: group,
        onSubmit: ({
          required String title,
          required String photoDateIso,
        }) async {
          final err = await ref
              .read(placeDetailProvider(widget.pid).notifier)
              .patchPlacePhotoGroupMeta(
                pgid: group.pgid,
                photoType: widget.photoType,
                title: title,
                photoDate: photoDateIso,
              );
          return err;
        },
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(sheetCtx).height * 0.76,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: ResponsiveLayout.only(context,
                  left: 4, top: 2, right: 4, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: ResponsiveLayout.only(context, left: 12, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          rsV(context, 4),
                          Text(
                            _formatPhotoDateForSheet(group.photoDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_canEditGroupMeta(group, me))
                    IconButton(
                      tooltip: '작업명·업로드일 수정',
                      icon: Icon(Icons.edit_outlined, color: cs.primary),
                      onPressed: openGroupMetaEdit,
                    ),
                  IconButton(
                    tooltip: _selectionMode ? '선택 종료' : '항목 선택 후 공유',
                    onPressed: () {
                      if (_selectionMode) {
                        _leaveSelection();
                      } else if (!shareable) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('선택 공유 가능한 항목이 없습니다.')),
                        );
                      } else {
                        setState(() {
                          _selectionMode = true;
                          _selected.clear();
                        });
                      }
                    },
                    icon: Icon(
                      _selectionMode ? Icons.close : Icons.check_circle_outline,
                      color: shareable ? cs.primary : cs.outline,
                    ),
                  ),
                  IconButton(
                    tooltip: shareable ? '묶음 전체 공유' : '공유 불가',
                    onPressed: !shareable
                        ? () {
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                              const SnackBar(content: Text('공유 가능한 항목이 없습니다')),
                            );
                          }
                        : () => sharePlacePhotoOriginalEntries(
                              sheetCtx,
                              _entries,
                              placeDisplayName: widget.placeDisplayName,
                              groupTitle: group.title,
                            ),
                    icon: Icon(Icons.share_rounded, color: cs.primary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: ResponsiveLayout.only(context,
                  left: 16, right: 16, bottom: 6),
              child: Text(
                me?.canViewPlacePhotoDocuments(widget.photoType) == true
                    ? '탭해서 크게 보기 · 길게 눌러 메모 수정'
                    : '탭해서 크게 보기 · 길게 눌러 메모를 확인합니다.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_selectionMode)
              Padding(
                padding: ResponsiveLayout.only(context,
                    left: 16, right: 16, bottom: 4),
                child: Text(
                  '공유할 항목을 눌러 선택하세요.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: GridView.builder(
                padding: ResponsiveLayout.only(context,
                    left: 12, top: 12, right: 12, bottom: 8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: context.rs(8),
                  crossAxisSpacing: context.rs(8),
                  childAspectRatio: 1,
                ),
                itemCount: _entries.length,
                itemBuilder: (context, i) {
                  final sel = _selected.contains(i);
                  final e = _entries[i];
                  final ok = e.canFetchOriginalViaApi;
                  final hasMemo = e.hasMemo;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(context.rs(10)),
                      onLongPress: _selectionMode
                          ? null
                          : () async {
                              await showPlacePhotoMemoImageSheet(
                                sheetCtx,
                                ref: ref,
                                pid: widget.pid,
                                photoType: widget.photoType,
                                entry: e,
                                canEditMemoAndReplace: _canEditPhotoMemo(e, me),
                              );
                              // patchPlacePhoto 내부에서 이미 fetchPlacePhotoGroups를 호출하므로
                              // 별도의 invalidate 없이 자동으로 UI가 업데이트됨
                              // (_resolvedGroup()이 provider를 watch하고 있음)
                            },
                      onTap: () {
                        if (_selectionMode) {
                          _toggleIndex(i);
                        } else if (me?.canViewPlacePhotoDocuments(
                                    widget.photoType) ==
                                true &&
                            isPlacePhotoDocumentEntry(e)) {
                          Navigator.of(sheetCtx).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final host = rootNavigatorKey.currentContext;
                            if (host != null) {
                              openPlacePhotoOriginalDocument(host, entry: e);
                            }
                          });
                        } else {
                          _openFullscreenViewer(
                            context: sheetCtx,
                            pid: widget.pid,
                            photoType: widget.photoType,
                            placeDisplayName: widget.placeDisplayName,
                            groupTitle: group.title,
                            entries: _entries,
                            initialIndex: i,
                          );
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(context.rs(10)),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                              ),
                              child: _GalleryThumb(
                                url: e.displayUrl,
                                docHint: me?.canViewPlacePhotoDocuments(
                                            widget.photoType) ==
                                        true
                                    ? classifyPlaceDocumentForViewer(e)
                                    : null,
                              ),
                            ),
                            if (hasMemo)
                              Positioned(
                                top: context.rs(4),
                                right: context.rs(4),
                                child: Container(
                                  padding: ResponsiveLayout.all(context, 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.52),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Icon(
                                    Icons.sticky_note_2_outlined,
                                    size: context.rsi(13),
                                    color: Colors.amberAccent,
                                  ),
                                ),
                              ),
                            if (_selectionMode && sel)
                              ColoredBox(
                                color: cs.primary.withValues(alpha: 0.25),
                              ),
                            if (_selectionMode)
                              Align(
                                alignment: Alignment.topLeft,
                                child: Padding(
                                  padding: ResponsiveLayout.all(context, 6),
                                  child: _SelectionBadge(
                                      active: sel, disabled: !ok),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_selectionMode && _selected.isNotEmpty)
              Material(
                elevation: 3,
                color: cs.surfaceContainerHigh,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.rs(16),
                    context.rs(10),
                    context.rs(16),
                    bottomInset > 0 ? context.rs(8) : context.rs(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_selected.length}건 선택',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        icon: Icon(Icons.share_rounded, size: context.rsi(18)),
                        label: const Text('공유'),
                        onPressed: () => _shareSelected(sheetCtx),
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

class _SelectionBadge extends StatelessWidget {
  const _SelectionBadge({required this.active, required this.disabled});

  final bool active;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          width: disabled ? 1.6 : 2,
          color: disabled
              ? Colors.black38
              : (active ? cs.primary : Colors.white.withValues(alpha: 0.92)),
        ),
        color: active && !disabled
            ? cs.primary
            : Colors.black.withValues(alpha: 0.35),
      ),
      child: active && !disabled
          ? Icon(Icons.check, size: 16, color: cs.onPrimary)
          : Icon(
              disabled ? Icons.block : Icons.check_box_outline_blank,
              size: 14,
              color: disabled ? Colors.black45 : Colors.white,
            ),
    );
  }
}

void _openFullscreenViewer({
  required BuildContext context,
  required int pid,
  required String photoType,
  required String placeDisplayName,
  required String groupTitle,
  required List<PlacePhotoEntry> entries,
  required int initialIndex,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    isDismissible: true,
    enableDrag: true,
    barrierColor: Colors.black87,
    backgroundColor: Colors.black,
    builder: (viewerCtx) => _FullscreenPhotoViewerSheet(
      pid: pid,
      photoType: photoType,
      placeDisplayName: placeDisplayName,
      groupTitle: groupTitle,
      entries: entries,
      initialIndex: initialIndex,
    ),
  );
}

class _FullscreenPhotoViewerSheet extends ConsumerStatefulWidget {
  const _FullscreenPhotoViewerSheet({
    required this.pid,
    required this.photoType,
    required this.placeDisplayName,
    required this.groupTitle,
    required this.entries,
    required this.initialIndex,
  });

  final int pid;
  final String photoType;
  final String placeDisplayName;
  final String groupTitle;
  final List<PlacePhotoEntry> entries;
  final int initialIndex;

  @override
  ConsumerState<_FullscreenPhotoViewerSheet> createState() =>
      _FullscreenPhotoViewerSheetState();
}

class _FullscreenPhotoViewerSheetState
    extends ConsumerState<_FullscreenPhotoViewerSheet> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.entries.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _memoTeaser(String? memo) {
    final t = memo?.trim() ?? '';
    if (t.isEmpty) return '메모가 없습니다. 탭해서 확인하거나 작성할 수 있습니다.';
    if (t.length <= 96) return t;
    return '${t.substring(0, 93)}…';
  }

  Future<void> _openMemoImagePanel(
      BuildContext ctx, PlacePhotoEntry cur) async {
    final me = ref
        .read(authSessionProvider)
        .maybeWhen(data: (u) => u, orElse: () => null);
    final saved = await showPlacePhotoMemoImageSheet(
      ctx,
      ref: ref,
      pid: widget.pid,
      photoType: widget.photoType,
      entry: cur,
      canEditMemoAndReplace: _canEditPhotoMemo(cur, me),
    );
    // patchPlacePhoto 내부에서 이미 fetchPlacePhotoGroups를 호출하므로
    // ref.invalidate 대신 setState만 호출하여 UI 업데이트
    if (saved == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final topPad = MediaQuery.viewPaddingOf(context).top;

    // Provider에서 최신 데이터를 가져와서 전체 사진 리스트를 업데이트
    final placeState = ref.watch(placeDetailProvider(widget.pid));

    // 현재 표시 중인 사진이 속한 그룹의 최신 데이터 찾기
    // 초기 entries의 첫 번째 사진의 phid를 기준으로 그룹을 찾음
    List<PlacePhotoEntry> currentEntries = widget.entries;
    if (widget.entries.isNotEmpty) {
      final firstPhid = widget.entries.first.phid;
      for (final group in placeState.photoGroupList) {
        for (final photo in group.photos) {
          if (photo.phid == firstPhid && firstPhid > 0) {
            currentEntries = group.photos;
            break;
          }
        }
        if (currentEntries != widget.entries) break;
      }
    }

    // 인덱스가 범위를 벗어나지 않도록 보정
    if (_index >= currentEntries.length && currentEntries.isNotEmpty) {
      _index = currentEntries.length - 1;
    }

    final cur = currentEntries.isNotEmpty
        ? currentEntries[_index]
        : widget.entries[_index];
    final me = ref
        .watch(authSessionProvider)
        .maybeWhen(data: (u) => u, orElse: () => null);
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      height: h * 0.94,
      child: Column(
        children: [
          SizedBox(height: topPad + context.rs(4)),
          Padding(
            padding:
                ResponsiveLayout.symmetric(context, horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded,
                      color: Colors.white, size: context.rsi(28)),
                  tooltip: '닫기',
                ),
                Expanded(
                  child: Text(
                    '${_index + 1} / ${currentEntries.length}',
                    textAlign: TextAlign.center,
                    style: tt.titleMedium?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: cur.canFetchOriginalViaApi ? '이 항목 공유' : '공유 불가',
                  icon: Icon(
                    Icons.share_rounded,
                    color: cur.canFetchOriginalViaApi
                        ? Colors.white
                        : Colors.white24,
                  ),
                  onPressed: !cur.canFetchOriginalViaApi
                      ? null
                      : () => sharePlacePhotoOriginalEntries(
                            context,
                            [cur],
                            placeDisplayName: widget.placeDisplayName,
                            groupTitle: widget.groupTitle,
                          ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: currentEntries.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final e = currentEntries[i];
                final pageDocTools =
                    me?.canViewPlacePhotoDocuments(widget.photoType) == true &&
                        e.canFetchOriginalViaApi;
                return _FullscreenPageContent(
                  entry: e,
                  docTools: pageDocTools,
                );
              },
            ),
          ),
          Material(
            color: Colors.black.withValues(alpha: 0.45),
            child: InkWell(
              onTap: () => _openMemoImagePanel(context, cur),
              child: Padding(
                padding: ResponsiveLayout.only(context,
                    left: 14, top: 8, right: 14, bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notes_rounded,
                            color: Colors.white54, size: context.rsi(18)),
                        rsH(context, 6),
                        Text(
                          '메모',
                          style: tt.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    rsV(context, 4),
                    Text(
                      _memoTeaser(cur.memo),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: cur.hasMemo ? Colors.white70 : Colors.white38,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenPageContent extends StatelessWidget {
  const _FullscreenPageContent({
    required this.entry,
    required this.docTools,
  });

  final PlacePhotoEntry entry;
  final bool docTools;

  @override
  Widget build(BuildContext context) {
    final kind = classifyPlaceDocumentForViewer(entry);
    final isDoc = isPlacePhotoDocumentEntry(entry);
    if (docTools && isDoc) {
      return _DocTapToOpenFullscreen(
        entry: entry,
        kind: kind == PlaceDocumentKind.imageOrOther ? null : kind,
      );
    }
    if (isDoc) {
      return const _Placeholder(
        icon: Icons.lock_outline_rounded,
        label: '문서 원본을 열 권한이 없습니다',
      );
    }
    return _ZoomableNetworkOrPlaceholder(url: entry.displayUrl);
  }
}

class _DocTapToOpenFullscreen extends StatelessWidget {
  const _DocTapToOpenFullscreen({
    required this.entry,
    this.kind,
  });

  final PlacePhotoEntry entry;
  final PlaceDocumentKind? kind;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final icon = kind == PlaceDocumentKind.pdf
        ? Icons.picture_as_pdf_outlined
        : (kind == PlaceDocumentKind.spreadsheetXlsx ||
                kind == PlaceDocumentKind.legacyXls)
            ? Icons.table_chart_outlined
            : Icons.description_outlined;
    final label = kind == PlaceDocumentKind.pdf
        ? 'PDF'
        : (kind == PlaceDocumentKind.spreadsheetXlsx ||
                kind == PlaceDocumentKind.legacyXls)
            ? '엑셀'
            : '문서';
    return Material(
      color: Colors.black,
      child: InkWell(
        onTap: () {
          final host = rootNavigatorKey.currentContext;
          if (host == null) return;
          Navigator.of(context).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = rootNavigatorKey.currentContext;
            if (ctx != null) {
              openPlacePhotoOriginalDocument(ctx, entry: entry);
            }
          });
        },
        child: Center(
          child: Padding(
            padding: ResponsiveLayout.all(context, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: context.rsi(72), color: Colors.white54),
                rsV(context, 16),
                Text(
                  '$label · 탭하여 열기',
                  textAlign: TextAlign.center,
                  style: tt.titleMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (entry.originalName != null &&
                    entry.originalName!.trim().isNotEmpty)
                  Padding(
                    padding: ResponsiveLayout.only(context, top: 8),
                    child: Text(
                      entry.originalName!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: tt.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomableNetworkOrPlaceholder extends StatelessWidget {
  const _ZoomableNetworkOrPlaceholder({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    if (isHttpImageUrl(url)) {
      return InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: PlaceNetworkImage(
            url: url,
            fit: BoxFit.contain,
            thumbCacheLogicalWidth: MediaQuery.sizeOf(context).width,
            placeholder: (context) => Skeletonizer(
              enabled: true,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Text(
                    '이미지',
                    style: tt.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ),
              ),
            ),
            errorBuilder: (_) => const _Placeholder(
              icon: Icons.broken_image_outlined,
              label: '이미지를 불러오지 못했습니다',
            ),
          ),
        ),
      );
    }
    return _LocalOrSeedPlaceholder(url: url);
  }
}

class _LocalOrSeedPlaceholder extends StatelessWidget {
  const _LocalOrSeedPlaceholder({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isCamera = url.startsWith('local://camera');
    return Center(
      child: Padding(
        padding: ResponsiveLayout.all(context, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCamera
                  ? Icons.photo_camera_outlined
                  : Icons.image_not_supported_outlined,
              size: context.rsi(56),
              color: Colors.white38,
            ),
            rsV(context, 14),
            Text(
              isCamera ? '로컬 미리보기만 지원된 이미지입니다' : '등록되지 않은 로컬 참조입니다',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: Colors.white54),
            ),
            rsV(context, 8),
            Text(
              url,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: tt.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({required this.url, this.docHint});

  final String url;
  final PlaceDocumentKind? docHint;

  @override
  Widget build(BuildContext context) {
    Widget core;
    if (isHttpImageUrl(url)) {
      final thumbW = MediaQuery.sizeOf(context).width / 4;
      core = PlaceNetworkImage(
        url: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        thumbCacheLogicalWidth: thumbW,
        errorBuilder: (_) => Icon(
          Icons.broken_image_outlined,
          color: Colors.black45,
          size: context.rsi(28),
        ),
      );
    } else {
      final isCam = url.startsWith('local://camera');
      core = Icon(
        isCam ? Icons.photo_camera : Icons.photo_outlined,
        color: Colors.black45,
        size: context.rsi(32),
      );
    }
    final showDoc =
        docHint != null && docHint != PlaceDocumentKind.imageOrOther;
    if (!showDoc) return core;
    final icon = docHint == PlaceDocumentKind.pdf
        ? Icons.picture_as_pdf_outlined
        : Icons.table_chart_outlined;
    return Stack(
      fit: StackFit.expand,
      children: [
        core,
        Positioned(
          left: context.rs(4),
          bottom: context.rs(4),
          child: Container(
            padding: ResponsiveLayout.all(context, 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(context.rs(6)),
            ),
            child: Icon(icon, size: context.rsi(14), color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white38, size: context.rsi(48)),
          rsV(context, 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white38,
                ),
          ),
        ],
      ),
    );
  }
}
