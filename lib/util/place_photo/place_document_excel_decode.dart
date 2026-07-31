import 'dart:math' as math;
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart' as sd;

const int kPlaceDocumentExcelMaxPreviewRows = 2000;

String excelCellToPlainString(xls.Data? cell) {
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

List<List<String>> sheetRowsAsStrings(xls.Sheet sheet) {
  final out = <List<String>>[];
  var n = 0;
  for (final row in sheet.rows) {
    if (n >= kPlaceDocumentExcelMaxPreviewRows) break;
    out.add(row.map(excelCellToPlainString).toList());
    n++;
  }
  return out;
}

int excelMaxColLen(List<List<String>> rows) {
  var m = 0;
  for (final r in rows) {
    m = math.max(m, r.length);
  }
  return m;
}

List<List<String>> padExcelRowsRectangular(List<List<String>> rows, int cols) {
  return rows.map((r) {
    final copy = List<String>.from(r);
    while (copy.length < cols) {
      copy.add('');
    }
    if (copy.length > cols) {
      return copy.sublist(0, cols);
    }
    return copy;
  }).toList();
}

String excelColumnLetters(int colIndexZeroBased) {
  var c = colIndexZeroBased + 1;
  final b = StringBuffer();
  while (c > 0) {
    c--;
    b.writeCharCode(65 + (c % 26));
    c ~/= 26;
  }
  return b.toString().split('').reversed.join();
}

List<List<String>> excelRectWithRowAndColumnHints(List<List<String>> rect) {
  if (rect.isEmpty) return rect;
  final header = rect.first;
  final body = rect.length <= 1 ? <List<String>>[] : rect.sublist(1);
  final displayHeader = <String>[
    '#',
    ...header.asMap().entries.map((e) {
      final t = e.value.trim();
      return t.isNotEmpty ? e.value : excelColumnLetters(e.key);
    }),
  ];
  final out = <List<String>>[displayHeader];
  for (var i = 0; i < body.length; i++) {
    out.add(<String>['${i + 1}', ...body[i]]);
  }
  return out;
}

class PlaceDocumentExcelDecoded {
  const PlaceDocumentExcelDecoded({
    required this.sheetNames,
    required this.sheetRows,
  });

  final List<String> sheetNames;
  final List<List<List<String>>> sheetRows;
}

PlaceDocumentExcelDecoded? decodePlaceDocumentXlsx(Uint8List bytes) {
  try {
    final ex = xls.Excel.decodeBytes(bytes);
    final names = ex.tables.keys.toList();
    final rows = <List<List<String>>>[];
    for (final name in names) {
      rows.add(sheetRowsAsStrings(ex.tables[name]!));
    }
    if (names.isEmpty) return null;
    return PlaceDocumentExcelDecoded(sheetNames: names, sheetRows: rows);
  } catch (e) {
    try {
      final dec = sd.SpreadsheetDecoder.decodeBytes(bytes);
      final names = dec.tables.keys.toList();
      if (names.isEmpty) return null;
      final rows = <List<List<String>>>[];
      for (final name in names) {
        final table = dec.tables[name]!;
        final out = <List<String>>[];
        var n = 0;
        for (final row in table.rows) {
          if (n >= kPlaceDocumentExcelMaxPreviewRows) break;
          out.add(row.map((c) => c?.toString() ?? '').toList());
          n++;
        }
        rows.add(out);
      }
      return PlaceDocumentExcelDecoded(sheetNames: names, sheetRows: rows);
    } catch (_) {
      return null;
    }
  }
}
