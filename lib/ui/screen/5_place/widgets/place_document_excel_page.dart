import 'dart:io';
import 'dart:math' as math;

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart' hide Border;
import 'package:flutter/services.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart' as sd;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:w0001/util/responsive_layout.dart';

const int _kMaxPreviewRows = 2000;

String _excelCellToPlainString(xls.Data? cell) {
  if (cell == null) return '';
  final v = cell.value;
  if (v == null) return '';
  if (v is xls.TextCellValue) {
    final span = v.value;
    final direct = span.text;
    if (direct != null && direct.isNotEmpty) return direct;
    final b = StringBuffer();
    void walk(InlineSpan s) {
      if (s is TextSpan) {
        if (s.text != null) b.write(s.text);
        for (final c in s.children ?? const <InlineSpan>[]) {
          walk(c);
        }
      }
    }
    walk(span as InlineSpan);
    return b.toString();
  }
  if (v is xls.IntCellValue) return v.value.toString();
  if (v is xls.DoubleCellValue) {
    final d = v.value;
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toString();
  }
  if (v is xls.BoolCellValue) return v.value ? 'TRUE' : 'FALSE';
  if (v is xls.FormulaCellValue) return v.formula;
  if (v is xls.DateCellValue) {
    return v.asDateTimeLocal().toIso8601String().split('T').first;
  }
  return v.toString();
}

List<List<String>> _sheetRowsAsStrings(xls.Sheet sheet) {
  final out = <List<String>>[];
  var n = 0;
  for (final row in sheet.rows) {
    if (n >= _kMaxPreviewRows) break;
    out.add(row.map(_excelCellToPlainString).toList());
    n++;
  }
  return out;
}

int _maxColLen(List<List<String>> rows) {
  var m = 0;
  for (final r in rows) {
    m = math.max(m, r.length);
  }
  return m;
}

List<List<String>> _padRowsRectangular(List<List<String>> rows, int cols) {
  return rows
      .map((r) {
        final copy = List<String>.from(r);
        while (copy.length < cols) {
          copy.add('');
        }
        if (copy.length > cols) {
          return copy.sublist(0, cols);
        }
        return copy;
      })
      .toList();
}

/// 엑셀식 열 문자 (0 → A, 25 → Z, 26 → AA).
String _excelColumnLetters(int colIndexZeroBased) {
  var c = colIndexZeroBased + 1;
  final b = StringBuffer();
  while (c > 0) {
    c--;
    b.writeCharCode(65 + (c % 26));
    c ~/= 26;
  }
  return b.toString().split('').reversed.join();
}

/// 미리보기용: 첫 열 행 번호, 헤더가 비면 열 문자(A,B…) 표시.
List<List<String>> _rectWithRowAndColumnHints(List<List<String>> rect) {
  if (rect.isEmpty) return rect;
  final header = rect.first;
  final body = rect.length <= 1 ? <List<String>>[] : rect.sublist(1);
  final displayHeader = <String>[
    '#',
    ...header.asMap().entries.map((e) {
      final t = e.value.trim();
      return t.isNotEmpty ? e.value : _excelColumnLetters(e.key);
    }),
  ];
  final out = <List<String>>[displayHeader];
  for (var i = 0; i < body.length; i++) {
    out.add(<String>['${i + 1}', ...body[i]]);
  }
  return out;
}

String _spreadsheetDecoderCellToString(Object? cell) {
  if (cell == null) return '';
  return cell.toString();
}

/// `excel` 패키지가 numFmtId 검증 등으로 실패할 때(WPS·Numbers·특정 서식) 가벼운 디코더로 시도.
void _decodeXlsxWithSpreadsheetDecoder(
  Uint8List bytes, {
  required void Function(List<String> names, List<List<List<String>>> rows)
      onSuccess,
  required void Function(Object error) onError,
}) {
  try {
    final dec = sd.SpreadsheetDecoder.decodeBytes(bytes);
    final names = dec.tables.keys.toList();
    final rows = <List<List<String>>>[];
    for (final name in names) {
      final table = dec.tables[name]!;
      final out = <List<String>>[];
      var n = 0;
      for (final row in table.rows) {
        if (n >= _kMaxPreviewRows) break;
        out.add(
          row.map(_spreadsheetDecoderCellToString).toList(),
        );
        n++;
      }
      rows.add(out);
    }
    onSuccess(names, rows);
  } catch (e) {
    onError(e);
  }
}

/// xlsx 원본을 표로 보여 주고, TSV 복사·엑셀 공유·표 인쇄(PDF 경유)를 제공한다.
class PlaceDocumentExcelPage extends StatefulWidget {
  const PlaceDocumentExcelPage({
    super.key,
    required this.bytes,
    required this.displayName,
  });

  final Uint8List bytes;
  final String displayName;

  @override
  State<PlaceDocumentExcelPage> createState() => _PlaceDocumentExcelPageState();
}

class _PlaceDocumentExcelPageState extends State<PlaceDocumentExcelPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<String> _sheetNames = const [];
  final List<List<List<String>>> _sheetRows = [];
  String? _error;
  int _tabIndex = 0;
  /// `Transform.scale` 대신 글자 크기만 조절 — 스크롤 영역과 실제 레이아웃이 일치한다.
  double _cellFontSize = 13;

  double _dataColumnWidth() =>
      (80 + _cellFontSize * 5.5).clamp(100.0, 228.0);

  void _applyDecodedSheets(List<String> names, List<List<List<String>>> rows) {
    _sheetNames = names;
    _sheetRows
      ..clear()
      ..addAll(rows);
    if (_sheetNames.isEmpty) {
      _error = '시트가 비어 있습니다.';
      return;
    }
    _error = null;
    _tabController = TabController(length: _sheetNames.length, vsync: this);
    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        setState(() => _tabIndex = _tabController!.index);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    try {
      final ex = xls.Excel.decodeBytes(widget.bytes);
      final names = ex.tables.keys.toList();
      final rows = <List<List<String>>>[];
      for (final name in names) {
        final sheet = ex.tables[name]!;
        rows.add(_sheetRowsAsStrings(sheet));
      }
      _applyDecodedSheets(names, rows);
    } catch (e) {
      _decodeXlsxWithSpreadsheetDecoder(
        widget.bytes,
        onSuccess: _applyDecodedSheets,
        onError: (_) {
          _error = e.toString();
        },
      );
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _openInExternalApp() async {
    try {
      final dir = await getTemporaryDirectory();
      var name =
          widget.displayName.replaceAll(RegExp(r'[/\\:?*"<>|]'), '_').trim();
      if (name.isEmpty) name = 'preview.xlsx';
      if (!name.toLowerCase().endsWith('.xlsx')) {
        name = '$name.xlsx';
      }
      final path =
          '${dir.path}/open_${DateTime.now().millisecondsSinceEpoch}_$name';
      await File(path).writeAsBytes(widget.bytes, flush: true);
      final r = await OpenFilex.open(path);
      if (!mounted) return;
      if (r.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일을 열 수 없습니다 (${r.message})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('열기 실패: $e')),
        );
      }
    }
  }

  Widget _buildReadabilityToolbar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 0.5,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Padding(
        padding: ResponsiveLayout.symmetric(context, horizontal: 2),
        child: Row(
          children: [
            IconButton(
              tooltip: '글자 작게',
              icon: Icon(Icons.text_decrease_rounded, size: context.rsi(22)),
              onPressed: () => setState(
                () => _cellFontSize = (_cellFontSize - 0.5).clamp(10.0, 20.0),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 2.5),
                child: Slider(
                  value: _cellFontSize,
                  min: 10,
                  max: 20,
                  divisions: 20,
                  label: '${_cellFontSize.round()} pt',
                  onChanged: (v) => setState(() => _cellFontSize = v),
                ),
              ),
            ),
            IconButton(
              tooltip: '글자 크게',
              icon: Icon(Icons.text_increase_rounded, size: context.rsi(22)),
              onPressed: () => setState(
                () => _cellFontSize = (_cellFontSize + 0.5).clamp(10.0, 20.0),
              ),
            ),
            IconButton(
              tooltip: '글자 크기 초기화',
              icon: Icon(Icons.format_size_rounded, size: context.rsi(22)),
              onPressed: () => setState(() => _cellFontSize = 13),
            ),
            SizedBox(
              width: context.rs(44),
              child: Text(
                '${_cellFontSize.round()} pt',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetTable(BuildContext context, List<List<String>> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('데이터가 없습니다.'));
    }
    final cols = math.max(1, _maxColLen(rows));
    final rect = _padRowsRectangular(rows, cols);
    final display = _rectWithRowAndColumnHints(rect);
    final header = display.first;
    final body = display.length <= 1 ? <List<String>>[] : display.sublist(1);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final headerBg = cs.surfaceContainerHighest.withValues(alpha: 0.92);
    final indexBg = cs.surfaceContainerHigh.withValues(alpha: 0.88);
    final borderCol = cs.outlineVariant.withValues(alpha: 0.75);
    final dataColW = _dataColumnWidth();
    final columnWidths = <int, TableColumnWidth>{
      for (var j = 0; j < header.length; j++)
        j: FixedColumnWidth(j == 0 ? context.rs(52) : dataColW),
    };
    final cellPad = ResponsiveLayout.symmetric(
      context,
      horizontal: 8,
      vertical: 5 + _cellFontSize * 0.06,
    );
    final baseFontSize = tt.bodySmall?.fontSize ?? 13;
    final textScale = _cellFontSize / baseFontSize;

    TableCell makeCell(
      String text, {
      required bool headerRow,
      required bool indexCol,
    }) {
      final bg = indexCol
          ? indexBg
          : (headerRow ? headerBg : Colors.transparent);
      final style = (headerRow ? tt.labelSmall : tt.bodySmall)?.copyWith(
        fontWeight: headerRow
            ? FontWeight.w800
            : (indexCol ? FontWeight.w600 : FontWeight.w400),
        color: indexCol ? cs.onSurfaceVariant : cs.onSurface,
        height: 1.3,
        fontFeatures: indexCol
            ? const [FontFeature.tabularFigures()]
            : null,
      );
      return TableCell(
        verticalAlignment: TableCellVerticalAlignment.top,
        child: Container(
          color: bg,
          padding: cellPad,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: Text(
              text.isEmpty ? ' ' : text,
              style: style,
              softWrap: true,
            ),
          ),
        ),
      );
    }

    final table = Table(
      border: TableBorder.all(color: borderCol, width: 0.5),
      columnWidths: columnWidths,
      children: [
        TableRow(
          children: [
            for (var i = 0; i < header.length; i++)
              makeCell(
                header[i],
                headerRow: true,
                indexCol: i == 0,
              ),
          ],
        ),
        for (final r in body)
          TableRow(
            children: [
              for (var i = 0; i < r.length; i++)
                makeCell(
                  r[i],
                  headerRow: false,
                  indexCol: i == 0,
                ),
            ],
          ),
      ],
    );

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        physics: const ClampingScrollPhysics(),
        padding: ResponsiveLayout.only(context, bottom: 16, left: 4),
        child: Scrollbar(
          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: ResponsiveLayout.only(context, right: 12),
            child: table,
          ),
        ),
      ),
    );
  }

  List<List<String>> get _currentRows {
    if (_sheetRows.isEmpty || _tabIndex >= _sheetRows.length) {
      return const [];
    }
    return _sheetRows[_tabIndex];
  }

  Future<void> _copyTableTsv() async {
    final rows = _currentRows;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('복사할 표 데이터가 없습니다.')),
      );
      return;
    }
    final buf = StringBuffer();
    for (final r in rows) {
      buf.writeln(
        r
            .map((c) => c.replaceAll('\t', ' ').replaceAll('\n', ' '))
            .join('\t'),
      );
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '「${_sheetNames[_tabIndex]}」 $_kMaxPreviewRows행까지 클립보드에 복사했습니다.',
        ),
      ),
    );
  }

  Future<void> _shareXlsx() async {
    final dir = await getTemporaryDirectory();
    var name = widget.displayName.replaceAll(RegExp(r'[/\\:?*"<>|]'), '_').trim();
    if (name.isEmpty) name = 'document.xlsx';
    if (!name.toLowerCase().endsWith('.xlsx')) {
      name = '$name.xlsx';
    }
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(widget.bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path)]),
    );
  }

  Future<pw.Font> _loadPrintFont() async {
    final bd = await rootBundle.load('assets/fonts/SCDream5.otf');
    return pw.Font.ttf(bd);
  }

  Future<void> _printTable() async {
    final rows = _currentRows;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인쇄할 표 데이터가 없습니다.')),
      );
      return;
    }
    final cols = _maxColLen(rows);
    final rect = _padRowsRectangular(rows, cols)
        .map((e) => e.map((c) => c as dynamic).toList())
        .toList();

    final font = await _loadPrintFont();
    final title =
        '${widget.displayName} — ${_sheetNames.isEmpty ? '' : _sheetNames[_tabIndex]}';
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font),
        build: (ctx) => [
          pw.Text(title,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            context: ctx,
            data: rect,
            headerCount: rect.isEmpty ? 0 : 1,
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerStyle: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
    final out = await doc.save();
    await Printing.layoutPdf(onLayout: (_) async => out);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('문서')),
        body: Padding(
          padding: ResponsiveLayout.all(context, 24),
          child: Center(
            child: Text(
              '엑셀을 읽지 못했습니다.\n$_error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }
    if (_tabController == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _sheetNames.map((n) => Tab(text: n)).toList(),
        ),
        actions: [
          IconButton(
            tooltip: '스프레드시트 앱에서 열기',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: _openInExternalApp,
          ),
          IconButton(
            tooltip: '표 복사(TSV)',
            icon: const Icon(Icons.copy_outlined),
            onPressed: _copyTableTsv,
          ),
          IconButton(
            tooltip: '엑셀 파일로 공유',
            icon: const Icon(Icons.table_chart_outlined),
            onPressed: _shareXlsx,
          ),
          IconButton(
            tooltip: '인쇄',
            icon: const Icon(Icons.print_outlined),
            onPressed: _printTable,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildReadabilityToolbar(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              // 가로 스크롤(표·시트 탭)과 겹치지 않게 탭 전환은 탭 바에서만 한다.
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(_sheetNames.length, (si) {
                return _buildSheetTable(context, _sheetRows[si]);
              }),
            ),
          ),
        ],
      ),
    );
  }
}
