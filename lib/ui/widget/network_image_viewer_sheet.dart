import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/ui/screen/announcements/announcement_image_strip_embed.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 네트워크 이미지 URL 목록 — 핀치·더블탭 확대 뷰어.
Future<void> showNetworkImageViewerSheet(
  BuildContext context, {
  required List<String> urls,
  int initialIndex = 0,
  String? title,
}) {
  final list = urls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (list.isEmpty) return Future.value();
  final start = initialIndex.clamp(0, list.length - 1);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    enableDrag: false,
    barrierColor: Colors.black87,
    backgroundColor: Colors.black,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height,
      child: _NetworkImageViewerSheet(
        urls: list,
        initialIndex: start,
        title: title,
      ),
    ),
  );
}

class _NetworkImageViewerSheet extends StatefulWidget {
  const _NetworkImageViewerSheet({
    required this.urls,
    required this.initialIndex,
    this.title,
  });

  final List<String> urls;
  final int initialIndex;
  final String? title;

  @override
  State<_NetworkImageViewerSheet> createState() =>
      _NetworkImageViewerSheetState();
}

class _NetworkImageViewerSheetState extends State<_NetworkImageViewerSheet> {
  late final PageController _page;
  late int _index;
  var _pageScrollLocked = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _onZoomChanged(bool zoomed) {
    if (_pageScrollLocked == zoomed) return;
    setState(() => _pageScrollLocked = zoomed);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.viewPaddingOf(context).top;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: widget.urls.length,
            physics: _pageScrollLocked
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            onPageChanged: (i) {
              setState(() {
                _index = i;
                _pageScrollLocked = false;
              });
            },
            itemBuilder: (_, i) => _ZoomableNetworkImage(
              key: ValueKey(widget.urls[i]),
              url: widget.urls[i],
              onZoomChanged: _onZoomChanged,
            ),
          ),
          Positioned(
            top: top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    widget.title ?? '${_index + 1} / ${widget.urls.length}',
                    textAlign: TextAlign.center,
                    style: tt.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomableNetworkImage extends StatefulWidget {
  const _ZoomableNetworkImage({
    super.key,
    required this.url,
    required this.onZoomChanged,
  });

  final String url;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableNetworkImage> createState() => _ZoomableNetworkImageState();
}

class _ZoomableNetworkImageState extends State<_ZoomableNetworkImage> {
  static const double _doubleTapScale = 2.5;

  final TransformationController _transform = TransformationController();
  var _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_notifyZoom);
  }

  @override
  void dispose() {
    _transform.removeListener(_notifyZoom);
    _transform.dispose();
    super.dispose();
  }

  void _notifyZoom() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (_zoomed == zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomChanged(zoomed);
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    final currentScale = _transform.value.getMaxScaleOnAxis();
    if (currentScale > 1.01) {
      _transform.value = Matrix4.identity();
      return;
    }

    final position = details.localPosition;
    final newScale = _doubleTapScale;
    final dx = -position.dx * (newScale - 1);
    final dy = -position.dy * (newScale - 1);

    _transform.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(newScale);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 5,
      panEnabled: _zoomed,
      scaleEnabled: true,
      clipBehavior: Clip.none,
      boundaryMargin: EdgeInsets.zero,
      child: GestureDetector(
        onDoubleTapDown: _handleDoubleTapDown,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: announcementEmbedImage(
            widget.url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Skeletonizer(
                enabled: true,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(context.rsi(24)),
                      child: Text(
                        '이미지',
                        style: tt.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
