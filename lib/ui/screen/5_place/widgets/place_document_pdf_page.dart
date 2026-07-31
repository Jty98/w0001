import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

enum _PdfViewMode { slide, scroll }

/// PDF 원본 보기 — 슬라이드(가로 넘김·핀치 확대)·스크롤 전환, 가로 모드, 인쇄·공유.
///
/// 화면 탭으로 상·하단 오버레이를 토글해 문서를 최대한 크게 볼 수 있다.
class PlaceDocumentPdfPage extends StatefulWidget {
  const PlaceDocumentPdfPage({
    super.key,
    required this.bytes,
    required this.displayName,
  });

  final Uint8List bytes;
  final String displayName;

  @override
  State<PlaceDocumentPdfPage> createState() => _PlaceDocumentPdfPageState();
}

class _PlaceDocumentPdfPageState extends State<PlaceDocumentPdfPage> {
  _PdfViewMode _mode = _PdfViewMode.slide;
  final PdfViewerController _slideController = PdfViewerController();
  int _slidePage = 1;
  int _slidePageCount = 0;
  bool _chromeVisible = false;
  bool _interactionScaled = false;
  Offset? _interactionStart;
  Offset? _interactionLastFocal;

  @override
  void initState() {
    super.initState();
    _allowViewerOrientations();
    _applyChromeSystemUi();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _restorePortraitOrientations();
    super.dispose();
  }

  Future<void> _allowViewerOrientations() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _restorePortraitOrientations() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  void _applyChromeSystemUi() {
    SystemChrome.setEnabledSystemUIMode(
      _chromeVisible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  void _setChromeVisible(bool visible) {
    if (_chromeVisible == visible) return;
    setState(() => _chromeVisible = visible);
    _applyChromeSystemUi();
  }

  void _toggleChrome() => _setChromeVisible(!_chromeVisible);

  void _onInteractionStart(ScaleStartDetails details) {
    _interactionStart = details.focalPoint;
    _interactionLastFocal = details.focalPoint;
    _interactionScaled = false;
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    _interactionLastFocal = details.focalPoint;
    if ((details.scale - 1.0).abs() > 0.015) {
      _interactionScaled = true;
    }
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    if (_interactionScaled) {
      _interactionStart = null;
      _interactionLastFocal = null;
      return;
    }
    final start = _interactionStart;
    final end = _interactionLastFocal;
    _interactionStart = null;
    _interactionLastFocal = null;
    if (start == null || end == null) return;
    if ((end - start).distance < 26) {
      _toggleChrome();
    }
  }

  Future<void> _print() async {
    await Printing.layoutPdf(onLayout: (_) async => widget.bytes);
  }

  Future<void> _share() async {
    final dir = await getTemporaryDirectory();
    var name =
        widget.displayName.replaceAll(RegExp(r'[/\\:?*"<>|]'), '_').trim();
    if (name.isEmpty) name = 'document.pdf';
    if (!name.toLowerCase().endsWith('.pdf')) {
      name = '$name.pdf';
    }
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(widget.bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path)]),
    );
  }

  void _copyFileName(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.displayName));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('파일 이름을 클립보드에 복사했습니다.')),
    );
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == _PdfViewMode.slide
          ? _PdfViewMode.scroll
          : _PdfViewMode.slide;
    });
  }

  PdfViewerParams _baseViewerParams({
    PdfPageLayout Function(List<PdfPage>, PdfViewerParams)? layoutPages,
    void Function(int?)? onPageChanged,
    void Function(PdfDocument, PdfViewerController)? onViewerReady,
    double? Function(PdfDocument, PdfViewerController, double, double)?
        calculateInitialZoom,
  }) {
    return PdfViewerParams(
      margin: 12,
      panAxis: PanAxis.free,
      scaleEnabled: true,
      panEnabled: true,
      layoutPages: layoutPages,
      onPageChanged: onPageChanged,
      onViewerReady: onViewerReady,
      calculateInitialZoom: calculateInitialZoom,
      onInteractionStart: _onInteractionStart,
      onInteractionUpdate: _onInteractionUpdate,
      onInteractionEnd: _onInteractionEnd,
    );
  }

  PdfViewerParams get _slideParams => _baseViewerParams(
        layoutPages: _horizontalSlideLayout,
        onPageChanged: (page) {
          if (page != null && page != _slidePage) {
            setState(() => _slidePage = page);
          }
        },
        onViewerReady: (document, controller) {
          final count = document.pages.length;
          if (count == 0) return;
          if (_slidePageCount != count) {
            setState(() {
              _slidePageCount = count;
              _slidePage = 1;
            });
          }
        },
        calculateInitialZoom: (document, controller, fitZoom, coverZoom) {
          final layouts = controller.layout.pageLayouts;
          if (controller.viewSize.width <= 0 || layouts.isEmpty) {
            return fitZoom;
          }
          final page = layouts.first;
          return (controller.viewSize.width - 12 * 2) / page.width;
        },
      );

  PdfViewerParams get _scrollParams => _baseViewerParams();

  Widget _buildPdfViewer() {
    if (_mode == _PdfViewMode.scroll) {
      return PdfViewer.data(
        widget.bytes,
        sourceName: widget.displayName,
        params: _scrollParams,
      );
    }
    return PdfViewer.data(
      widget.bytes,
      sourceName: widget.displayName,
      controller: _slideController,
      params: _slideParams,
    );
  }

  Widget _buildTopChrome(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return IgnorePointer(
      ignoring: !_chromeVisible,
      child: AnimatedOpacity(
        opacity: _chromeVisible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.72),
                Colors.black.withValues(alpha: 0.35),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: Row(
              children: [
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    widget.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: _mode == _PdfViewMode.slide ? '스크롤 보기' : '슬라이드 보기',
                  onPressed: _toggleMode,
                  icon: Icon(
                    _mode == _PdfViewMode.slide
                        ? Icons.view_agenda_outlined
                        : Icons.view_carousel_outlined,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  tooltip: '파일명 복사',
                  onPressed: () => _copyFileName(context),
                  icon: const Icon(Icons.copy_outlined, color: Colors.white),
                ),
                IconButton(
                  tooltip: '다른 앱으로 공유',
                  onPressed: _share,
                  icon: const Icon(Icons.share_outlined, color: Colors.white),
                ),
                IconButton(
                  tooltip: '인쇄',
                  onPressed: _print,
                  icon: const Icon(Icons.print_outlined, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomChrome(BuildContext context) {
    if (_mode != _PdfViewMode.slide || _slidePageCount <= 0) {
      return const SizedBox.shrink();
    }
    final bottom = MediaQuery.paddingOf(context).bottom;
    return IgnorePointer(
      ignoring: !_chromeVisible,
      child: AnimatedOpacity(
        opacity: _chromeVisible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom + 12),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '$_slidePage / $_slidePageCount',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBack(BuildContext context) {
    if (_chromeVisible) return const SizedBox.shrink();
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: top + 8,
      left: 8,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        child: IconButton(
          tooltip: '닫기',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildChromeMenuButton(BuildContext context) {
    if (_chromeVisible) return const SizedBox.shrink();
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: top + 8,
      right: 8,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        child: IconButton(
          tooltip: '메뉴',
          onPressed: _toggleChrome,
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: cs.surfaceContainerLow,
            child: _buildPdfViewer(),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopChrome(context),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomChrome(context),
          ),
          _buildFloatingBack(context),
          _buildChromeMenuButton(context),
        ],
      ),
    );
  }
}

PdfPageLayout _horizontalSlideLayout(
  List<PdfPage> pages,
  PdfViewerParams params,
) {
  final margin = params.margin;
  final height = pages.fold<double>(
        0,
        (prev, page) => max(prev, page.height),
      ) +
      margin * 2;
  final layouts = <Rect>[];
  var x = margin;
  for (final page in pages) {
    layouts.add(
      Rect.fromLTWH(
        x,
        margin + (height - margin * 2 - page.height) / 2,
        page.width,
        page.height,
      ),
    );
    x += page.width + margin;
  }
  return PdfPageLayout(pageLayouts: layouts, documentSize: Size(x, height));
}
