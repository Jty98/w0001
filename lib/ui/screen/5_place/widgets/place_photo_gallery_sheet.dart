import 'package:flutter/material.dart';
import 'package:w0001/data/model/place_photo_entry.dart';
import 'package:w0001/data/model/place_photo_group_model.dart';
import 'package:w0001/util/place_photo/share_place_photo_originals.dart';

/// 현장 사진 그룹: 그리드 갤러리 → 썸네일 탭 시 풀 바텀시트 + 좌우 스와이프 확대 뷰.
Future<void> showPlacePhotoGroupGallerySheet(
  BuildContext context,
  PlacePhotoGroupModel group,
) {
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
    builder: (sheetCtx) => _PlacePhotoGallerySheet(group: group),
  );
}

class _PlacePhotoGallerySheet extends StatefulWidget {
  const _PlacePhotoGallerySheet({required this.group});

  final PlacePhotoGroupModel group;

  @override
  State<_PlacePhotoGallerySheet> createState() => _PlacePhotoGallerySheetState();
}

class _PlacePhotoGallerySheetState extends State<_PlacePhotoGallerySheet> {
  bool _selectionMode = false;
  final Set<int> _selected = <int>{};

  List<PlacePhotoEntry> get _entries => widget.group.photos;

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
        const SnackBar(
          content: Text('연결된 사진만 선택해 공유할 수 있습니다.'),
        ),
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
    final list =
        _selected.map((i) => _entries[i]).where((e) => e.canFetchOriginalViaApi).toList();
    if (list.isEmpty) return;
    await sharePlacePhotoOriginalEntries(sheetCtx, list);
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

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(sheetCtx).height * 0.76,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Text(
                        '${widget.group.photoDate} · ${widget.group.title}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip:
                        _selectionMode ? '선택 종료' : '사진 선택 후 공유',
                    onPressed: () {
                      if (_selectionMode) {
                        _leaveSelection();
                      } else if (!shareable) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '선택 공유 가능한 항목이 없습니다.',
                            ),
                          ),
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
                    tooltip: shareable ? '묶음 전체 사진 공유' : '사진 공유 불가',
                    onPressed: !shareable
                        ? () {
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '공유 가능한 사진이 없습니다',
                                ),
                              ),
                            );
                          }
                        : () => sharePlacePhotoOriginalEntries(
                              sheetCtx,
                              _entries,
                            ),
                    icon: Icon(Icons.share_rounded, color: cs.primary),
                  ),
                ],
              ),
            ),
            if (_selectionMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  '공유할 사진을 눌러 선택하세요.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _entries.length,
                itemBuilder: (context, i) {
                  final sel = _selected.contains(i);
                  final e = _entries[i];
                  final ok = e.canFetchOriginalViaApi;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (_selectionMode) {
                          _toggleIndex(i);
                        } else {
                          _openFullscreenViewer(
                            context: sheetCtx,
                            entries: _entries,
                            initialIndex: i,
                          );
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                              ),
                              child: _GalleryThumb(url: e.displayUrl),
                            ),
                            if (_selectionMode && sel)
                              ColoredBox(
                                color:
                                    cs.primary.withValues(alpha: 0.25),
                              ),
                            if (_selectionMode)
                              Align(
                                alignment: Alignment.topLeft,
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: _SelectionBadge(
                                    active: sel,
                                    disabled: !ok,
                                  ),
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
                  padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset > 0 ? 8 : 12),
                  child: Row(
                    children: [
                      Text(
                        '${_selected.length}장 선택',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('사진 공유'),
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
              size: disabled ? 14 : 14,
              color: disabled ? Colors.black45 : Colors.white,
            ),
    );
  }
}

void _openFullscreenViewer({
  required BuildContext context,
  required List<PlacePhotoEntry> entries,
  required int initialIndex,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    barrierColor: Colors.black87,
    backgroundColor: Colors.black,
    builder: (viewerCtx) => _FullscreenPhotoViewerSheet(
      entries: entries,
      initialIndex: initialIndex,
    ),
  );
}

class _FullscreenPhotoViewerSheet extends StatefulWidget {
  const _FullscreenPhotoViewerSheet({
    required this.entries,
    required this.initialIndex,
  });

  final List<PlacePhotoEntry> entries;
  final int initialIndex;

  @override
  State<_FullscreenPhotoViewerSheet> createState() =>
      _FullscreenPhotoViewerSheetState();
}

class _FullscreenPhotoViewerSheetState extends State<_FullscreenPhotoViewerSheet> {
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

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final topPad = MediaQuery.viewPaddingOf(context).top;
    final cur = widget.entries[_index];

    return SizedBox(
      height: h * 0.94,
      child: Column(
        children: [
          SizedBox(height: topPad + 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  tooltip: '닫기',
                ),
                Expanded(
                  child: Text(
                    '${_index + 1} / ${widget.entries.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: cur.canFetchOriginalViaApi
                      ? '이 사진 공유'
                      : '사진 공유 불가',
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
                          ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.entries.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                return _ZoomableNetworkOrPlaceholder(
                  url: widget.entries[i].displayUrl,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomableNetworkOrPlaceholder extends StatelessWidget {
  const _ZoomableNetworkOrPlaceholder({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (_isHttpUrl(url)) {
      return InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white.withValues(alpha: 0.8),
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => const _Placeholder(
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
    final isCamera = url.startsWith('local://camera');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCamera ? Icons.photo_camera_outlined : Icons.image_not_supported_outlined,
              size: 56,
              color: Colors.white38,
            ),
            const SizedBox(height: 14),
            Text(
              isCamera ? '로컬 미리보기만 지원된 이미지입니다' : '등록되지 않은 로컬 참조입니다',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              url,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (_isHttpUrl(url)) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image_outlined,
          color: Colors.black45,
          size: 28,
        ),
      );
    }
    final isCam = url.startsWith('local://camera');
    return Icon(
      isCam ? Icons.photo_camera : Icons.photo_outlined,
      color: Colors.black45,
      size: 32,
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
          Icon(icon, color: Colors.white38, size: 48),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}

bool _isHttpUrl(String s) =>
    s.startsWith('http://') || s.startsWith('https://');
