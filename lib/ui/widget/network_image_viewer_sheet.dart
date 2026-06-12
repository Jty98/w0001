import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 네트워크 이미지 URL 목록 — 현장사진 확대와 동일하게 [InteractiveViewer]로 본다.
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
    barrierColor: Colors.black87,
    backgroundColor: Colors.black,
    builder: (ctx) => _NetworkImageViewerSheet(
      urls: list,
      initialIndex: start,
      title: title,
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
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _ZoomableNetworkImage(url: widget.urls[i]),
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
                    widget.title ??
                        '${_index + 1} / ${widget.urls.length}',
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

class _ZoomableNetworkImage extends StatelessWidget {
  const _ZoomableNetworkImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: Image.network(
          url,
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
    );
  }
}
