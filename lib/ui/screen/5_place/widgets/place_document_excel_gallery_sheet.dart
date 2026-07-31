import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_document_viewer_route.dart';
import 'package:w0001/util/place_photo/place_document_excel_decode.dart';

const int _kSheetMaxCols = 45;
const int _kSheetMaxRows = 600;
const double _kLetterRowHeight = 24;
const double _kDataRowHeight = 30;
const double _kIndexColWidth = 46;

const _kCornerBg = Color(0xFFD9D9D9);
const _kLetterBg = Color(0xFFE8E8E8);
const _kIndexBg = Color(0xFFF0F0F0);
const _kHeaderBg = Color(0xFF2F5597);
const _kHeaderText = Colors.white;
const _kGridLine = Color(0xFFADADAD);
const _kGridStrong = Color(0xFF5C5C5C);
const _kZebraBg = Color(0xFFF5F8FC);

/// iOS 전용 인앱 엑셀 뷰어. Android는 외부 앱으로 연다.
Future<void> showPlaceDocumentExcelGallerySheet(
  BuildContext context, {
  required Uint8List bytes,
  required String displayName,
}) {
  final nav = Navigator.of(context, rootNavigator: true);
  return nav.push<void>(
    PlaceDocumentViewerRoute<void>(
      childBuilder: (_) => PlaceDocumentExcelGallerySheet(
        bytes: bytes,
        displayName: displayName,
      ),
    ),
  );
}

class PlaceDocumentExcelGallerySheet extends StatefulWidget {
  const PlaceDocumentExcelGallerySheet({
    super.key,
    required this.bytes,
    required this.displayName,
  });

  final Uint8List bytes;
  final String displayName;

  @override
  State<PlaceDocumentExcelGallerySheet> createState() =>
      _PlaceDocumentExcelGallerySheetState();
}

class _PlaceDocumentExcelGallerySheetState
    extends State<PlaceDocumentExcelGallerySheet>
    with SingleTickerProviderStateMixin {
  PlaceDocumentExcelDecoded? _decoded;
  String? _error;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _decoded = decodePlaceDocumentXlsx(widget.bytes);
    if (_decoded == null) {
      _error = '엑셀 파일을 읽지 못했습니다.';
      return;
    }
    if (_decoded!.sheetNames.isEmpty) {
      _error = '시트가 비어 있습니다.';
      return;
    }
    _tabController = TabController(
      length: _decoded!.sheetNames.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  List<List<String>> _rowsAt(int index) {
    final d = _decoded;
    if (d == null || index >= d.sheetRows.length) return const [];
    return d.sheetRows[index];
  }

  Future<void> _copyTsv() async {
    final i = _tabController?.index ?? 0;
    final rows = _rowsAt(i);
    if (rows.isEmpty) return;
    final buf = StringBuffer();
    for (final r in rows) {
      buf.writeln(
        r.map((c) => c.replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t'),
      );
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('표 내용을 클립보드에 복사했습니다.')),
    );
  }

  Future<void> _shareFile() async {
    final dir = await getTemporaryDirectory();
    var name =
        widget.displayName.replaceAll(RegExp(r'[/\\:?*"<>|]'), '_').trim();
    if (!name.toLowerCase().endsWith('.xlsx')) name = '$name.xlsx';
    final path = '${dir.path}/$name';
    await File(path).writeAsBytes(widget.bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
  }

  Widget _buildChromeBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: '닫기',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text(
              widget.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: '표 복사',
            onPressed: _copyTsv,
            icon: const Icon(Icons.copy_outlined, color: Colors.white),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: theme.colorScheme.surfaceContainerHigh,
            onSelected: (v) {
              if (v == 'share') _shareFile();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'share', child: Text('파일 공유')),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decoded = _decoded;
    final tabs = _tabController;
    final theme = Theme.of(context);

    if (_error != null) {
      final top = MediaQuery.paddingOf(context).top;
      return PopScope(
        canPop: false,
        child: Material(
          color: Colors.black,
          child: Column(
            children: [
              SizedBox(height: top),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (decoded == null || tabs == null) {
      return const PopScope(
        canPop: false,
        child: Material(
          color: Colors.black,
          child: const AppLoadingIndicator(),
        ),
      );
    }

    final top = MediaQuery.paddingOf(context).top;

    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.black,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: top),
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.92),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildChromeBar(theme),
                  TabBar(
                    controller: tabs,
                    isScrollable: true,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    tabs: [for (final n in decoded.sheetNames) Tab(text: n)],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: tabs,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(
                  decoded.sheetNames.length,
                  (i) => _ZoomableExcelGrid(
                    key: ValueKey(i),
                    rows: _rowsAt(i),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomableExcelGrid extends StatefulWidget {
  const _ZoomableExcelGrid({super.key, required this.rows});

  final List<List<String>> rows;

  @override
  State<_ZoomableExcelGrid> createState() => _ZoomableExcelGridState();
}

class _ZoomableExcelGridState extends State<_ZoomableExcelGrid> {
  final _transform = TransformationController();
  final _contentKey = GlobalKey();
  int _fitAttempts = 0;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _fitToView(Size viewport) {
    if (_fitAttempts > 12) return;
    final content =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (content == null || !content.hasSize) {
      _scheduleFit(viewport);
      return;
    }

    final cs = content.size;
    if (cs.width <= 0 || cs.height <= 0) {
      _scheduleFit(viewport);
      return;
    }

    final scale = math
        .min(viewport.width * 0.98 / cs.width,
            viewport.height * 0.98 / cs.height)
        .clamp(0.05, 1.0);

    _transform.value = Matrix4.identity()
      ..translate(viewport.width / 2, viewport.height / 2)
      ..scale(scale)
      ..translate(-cs.width / 2, -cs.height / 2);
    _fitAttempts = 99;
  }

  void _scheduleFit(Size viewport) {
    _fitAttempts++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitToView(viewport);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (_fitAttempts == 0) {
          _scheduleFit(viewport);
        }

        return InteractiveViewer(
          transformationController: _transform,
          constrained: false,
          minScale: 0.05,
          maxScale: 8,
          panEnabled: true,
          scaleEnabled: true,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          child: ColoredBox(
            color: Colors.white,
            child: KeyedSubtree(
              key: _contentKey,
              child: buildExcelSheetTable(widget.rows),
            ),
          ),
        );
      },
    );
  }
}

List<List<String>> _rowsLimited(List<List<String>> rows) {
  final limited = rows.take(_kSheetMaxRows).toList();
  final cols = excelMaxColLen(limited).clamp(1, _kSheetMaxCols);
  return padExcelRowsRectangular(limited, cols);
}

List<List<String>> _buildExcelDisplayGrid(List<List<String>> rows) {
  final rect = _rowsLimited(rows);
  if (rect.isEmpty) return const [];
  final cols = rect.first.length;
  final header = rect.first;
  final body = rect.length > 1 ? rect.sublist(1) : <List<String>>[];

  return <List<String>>[
    ['', ...List.generate(cols, excelColumnLetters)],
    ['', ...header],
    for (var i = 0; i < body.length; i++) ['${i + 1}', ...body[i]],
  ];
}

bool _looksNumericCell(String text) {
  final t = text.trim();
  if (t.isEmpty) return false;
  return RegExp(r'^-?[\d,]+(\.\d+)?%?$').hasMatch(t.replaceAll(',', ''));
}

double _colWidth(List<List<String>> grid, int col) {
  if (col == 0) return _kIndexColWidth;
  var maxLen = 4;
  for (final r in grid) {
    if (col >= r.length) continue;
    maxLen = math.max(maxLen, r[col].trim().length.clamp(0, 48));
  }
  return (maxLen * 7.8 + 18).clamp(60.0, 240.0);
}

Widget buildExcelSheetTable(List<List<String>> rows) {
  final grid = _buildExcelDisplayGrid(rows);
  if (grid.isEmpty) {
    return const SizedBox(
      width: 280,
      height: 120,
      child: Center(child: Text('데이터가 없습니다.')),
    );
  }
  return _buildExcelTableSection(
    grid,
    rowStart: 0,
    rowEndExclusive: grid.length,
  );
}

Widget _buildExcelTableSection(
  List<List<String>> grid, {
  required int rowStart,
  required int rowEndExclusive,
}) {
  if (rowStart >= rowEndExclusive) {
    return const SizedBox.shrink();
  }
  final cols = grid.first.length;

  return Table(
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    columnWidths: {
      for (var j = 0; j < cols; j++) j: FixedColumnWidth(_colWidth(grid, j)),
    },
    border: TableBorder.symmetric(
      inside: const BorderSide(color: _kGridLine, width: 0.5),
      outside: const BorderSide(color: _kGridStrong, width: 1.2),
    ),
    children: [
      for (var ri = rowStart; ri < rowEndExclusive; ri++)
        TableRow(
          children: [
            for (var ci = 0; ci < cols; ci++)
              _buildGridCell(
                text: grid[ri][ci],
                colIndex: ci,
                rowIndex: ri,
              ),
          ],
        ),
    ],
  );
}

TableCell _buildGridCell({
  required String text,
  required int colIndex,
  required int rowIndex,
}) {
  final isLetterRow = rowIndex == 0;
  final isHeaderRow = rowIndex == 1;
  final isBody = rowIndex > 1;
  final isIndexCol = colIndex == 0;
  final zebra = isBody && rowIndex.isEven;

  Color bg;
  if (isLetterRow) {
    bg = isIndexCol ? _kCornerBg : _kLetterBg;
  } else if (isHeaderRow) {
    bg = isIndexCol ? _kCornerBg : _kHeaderBg;
  } else if (isIndexCol) {
    bg = _kIndexBg;
  } else {
    bg = zebra ? _kZebraBg : Colors.white;
  }

  TextStyle style;
  if (isLetterRow && !isIndexCol) {
    style = const TextStyle(
      fontSize: 11,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: Color(0xFF404040),
    );
  } else if (isHeaderRow && !isIndexCol) {
    style = const TextStyle(
      fontSize: 12.5,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: _kHeaderText,
    );
  } else if (isIndexCol && isBody) {
    style = const TextStyle(
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: Color(0xFF505050),
      fontFeatures: [FontFeature.tabularFigures()],
    );
  } else {
    final numeric = _looksNumericCell(text);
    style = TextStyle(
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w400,
      color: Colors.black.withValues(alpha: 0.9),
      fontFeatures: numeric ? const [FontFeature.tabularFigures()] : null,
    );
  }

  final align = (isLetterRow && !isIndexCol) || (isIndexCol && isBody)
      ? TextAlign.center
      : (_looksNumericCell(text) ? TextAlign.right : TextAlign.left);

  final bottomWidth = isHeaderRow ? 2.5 : (isLetterRow ? 1.2 : 0.5);
  final bottomColor = isHeaderRow ? const Color(0xFF1F3864) : _kGridLine;
  final rightWidth = isIndexCol ? 1.8 : 0.5;
  final rightColor = isIndexCol ? _kGridStrong : _kGridLine;

  return TableCell(
    verticalAlignment: TableCellVerticalAlignment.middle,
    child: Container(
      constraints: BoxConstraints(
        minHeight: isLetterRow ? _kLetterRowHeight : _kDataRowHeight,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          right: BorderSide(color: rightColor, width: rightWidth),
          bottom: BorderSide(color: bottomColor, width: bottomWidth),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Text(
        text.isEmpty ? ' ' : text,
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: style,
      ),
    ),
  );
}
