import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

String _columnLetter(int oneBasedColumn) {
  var result = '';
  var c = oneBasedColumn;
  while (c > 0) {
    c--;
    result = String.fromCharCode('A'.codeUnitAt(0) + c % 26) + result;
    c ~/= 26;
  }
  return result;
}

/// `.xlsx` 바이트에 시트 뷰 고정(틀 고정)을 주입합니다.
///
/// [frozenRows]·[frozenColumns]는 Excel 1-based 기준으로, 해당 행·열까지 고정합니다.
/// 예: `frozenRows: 5`, `frozenColumns: 1` → 5행·A열 고정, 스크롤 시작 셀 `B6`.
Uint8List applyXlsxFreezePanes(
  Uint8List xlsxBytes, {
  required int frozenRows,
  required int frozenColumns,
}) {
  if (frozenRows < 1 && frozenColumns < 1) return xlsxBytes;

  final archive = ZipDecoder().decodeBytes(xlsxBytes);
  var patched = false;

  for (final i in List.generate(archive.length, (i) => i)) {
    final file = archive[i];
    final name = file.name;
    if (!name.startsWith('xl/worksheets/sheet') || !name.endsWith('.xml')) {
      continue;
    }

    final xmlText = utf8.decode(file.content as List<int>);
    final doc = XmlDocument.parse(xmlText);
    final sheetViews = doc.findAllElements('sheetView');
    if (sheetViews.isEmpty) continue;

    final sheetView = sheetViews.first;
    sheetView.findAllElements('pane').forEach((e) => e.remove());
    sheetView.findAllElements('selection').forEach((e) => e.remove());

    final topLeftCol = _columnLetter(frozenColumns + 1);
    final topLeftRow = frozenRows + 1;
    final topLeftCell = '$topLeftCol$topLeftRow';

    final activePane = switch ((frozenRows > 0, frozenColumns > 0)) {
      (true, true) => 'bottomRight',
      (true, false) => 'bottomLeft',
      (false, true) => 'topRight',
      (false, false) => 'bottomLeft',
    };

    final paneAttrs = <XmlAttribute>[
      if (frozenColumns > 0)
        XmlAttribute(XmlName('xSplit'), frozenColumns.toString()),
      if (frozenRows > 0)
        XmlAttribute(XmlName('ySplit'), frozenRows.toString()),
      XmlAttribute(XmlName('topLeftCell'), topLeftCell),
      XmlAttribute(XmlName('activePane'), activePane),
      XmlAttribute(XmlName('state'), 'frozen'),
    ];

    sheetView.children.insert(
      0,
      XmlElement(XmlName('pane'), paneAttrs),
    );
    sheetView.children.insert(
      1,
      XmlElement(
        XmlName('selection'),
        [
          XmlAttribute(XmlName('pane'), activePane),
          XmlAttribute(XmlName('activeCell'), topLeftCell),
          XmlAttribute(XmlName('sqref'), topLeftCell),
        ],
      ),
    );

    final outBytes = utf8.encode(doc.toXmlString());
    archive[i] = ArchiveFile(name, outBytes.length, outBytes);
    patched = true;
  }

  if (!patched) return xlsxBytes;

  final encoded = ZipEncoder().encode(archive);
  return encoded == null ? xlsxBytes : Uint8List.fromList(encoded);
}
