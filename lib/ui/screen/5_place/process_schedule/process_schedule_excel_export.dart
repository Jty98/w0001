import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart' hide Border, BorderStyle;
import 'package:w0001/domain/process_schedule/process_schedule_editor.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/domain/process_schedule/process_schedule_palette.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_helpers.dart';
import 'package:w0001/util/xlsx_freeze_panes_patch.dart';

/// `excel` 패키지 저장 시 [Save]는 `fgColor` 문자열이 **`FF`로 시작**(불투명 ARGB)할 때만
/// solid fill 블록을 씁니다. 알파만 `EB…`인 8자(hex)는 패턴이 빠져 배경이 전혀 안 나옵니다.
/// → 화면에 맞게 블렌딩한 뒤, 엑셀용으로는 불투명 `FF······`(RRGGBB)로 고정합니다.
String _opaqueArgbHex(Color c) {
  final r = (c.r.clamp(0.0, 1.0) * 255).round();
  final g = (c.g.clamp(0.0, 1.0) * 255).round();
  final b = (c.b.clamp(0.0, 1.0) * 255).round();
  return 'FF'
          '${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

Color _neutralCellApprox() => const Color.fromARGB(255, 250, 252, 255);

/// 앱 [onBarLabelColor]와 동일: 막대 **원색** 기준 명도로 흑/백 선택.
ExcelColor _excelFgOnBar(ProcessScheduleTask task) {
  final bar = Color(ProcessSchedulePalette.argbAt(task.paletteIndex));
  return bar.computeLuminance() > 0.55 ? ExcelColor.grey900 : ExcelColor.white;
}

ExcelColor _excelBg(ProcessScheduleTask task, bool scheduled) {
  if (!scheduled) {
    return ExcelColor.fromHexString(_opaqueArgbHex(_neutralCellApprox()));
  }
  final bar = Color(ProcessSchedulePalette.argbAt(task.paletteIndex));
  // 앱 셀: 막대색 알파 높임 — 엑셀에서는 동일처럼 흰색 위에 블렌드한 결과 RGB 저장
  final blended = Color.alphaBlend(
    bar.withValues(alpha: 0.92),
    Colors.white,
  );
  return ExcelColor.fromHexString(_opaqueArgbHex(blended));
}

Border _thinGrid() =>
    Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.grey400);

ExcelColor _headerDayFg(DateTime d) {
  if (d.weekday == DateTime.sunday) {
    return ExcelColor.red900;
  }
  if (d.weekday == DateTime.saturday) {
    return ExcelColor.indigo800;
  }
  return ExcelColor.grey900;
}

String _ellipsis(String s, int max) => s.runes.length <= max
    ? s
    : '${String.fromCharCodes(s.runes.take(max - 1))}…';

/// 공정표 한 장을 표 형식(.xlsx)으로 직렬화합니다.
///
/// 과거 버전에서는 셀 병합 후 본문 `updateCell`이 병합/스패닝 처리와 충돌해
/// 날짜 열 데이터가 빠지거나 덮였을 수 있어, 병합 없이 작성합니다.
Uint8List? buildProcessScheduleExcelBytes({
  required ProcessScheduleData data,
  required String placeName,
}) {
  if (data.dayCount < 1) return null;

  final excel = Excel.createExcel();
  const sheetName = '공정표';
  final sheet = excel[sheetName];
  try {
    excel.delete('Sheet1');
  } catch (_) {}

  final dates = ProcessScheduleEditor.columnDates(data);
  final lastCol = data.dayCount;

  final now = DateTime.now();
  final exported =
      '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} '
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  sheet.updateCell(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    TextCellValue('$placeName — 공정표'),
    cellStyle: CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.grey850,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    ),
  );

  sheet.updateCell(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
    TextCellValue('표시 기간: ${compactGridPeriodLine(data)}'),
    cellStyle: CellStyle(
      fontSize: 10,
      backgroundColorHex: ExcelColor.grey100,
      textWrapping: TextWrapping.WrapText,
      verticalAlign: VerticalAlign.Center,
    ),
  );

  sheet.updateCell(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2),
    TextCellValue('내보낸 시각: $exported'),
    cellStyle: CellStyle(
      fontSize: 10,
      backgroundColorHex: ExcelColor.grey100,
      verticalAlign: VerticalAlign.Center,
    ),
  );

  const headerRow = 4;

  sheet.updateCell(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRow),
    TextCellValue('구분'),
    cellStyle: CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.black,
      backgroundColorHex: ExcelColor.grey300,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      topBorder: _thinGrid(),
      bottomBorder: _thinGrid(),
      leftBorder: _thinGrid(),
      rightBorder: _thinGrid(),
    ),
  );

  for (var di = 0; di < dates.length; di++) {
    final day = dates[di];
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: di + 1, rowIndex: headerRow),
      TextCellValue(scheduleDateHeaderLabel(day)),
      cellStyle: CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: _headerDayFg(day),
        backgroundColorHex: ExcelColor.grey300,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        topBorder: _thinGrid(),
        bottomBorder: _thinGrid(),
        leftBorder: _thinGrid(),
        rightBorder: _thinGrid(),
      ),
    );
  }

  sheet.setColumnWidth(0, 28);
  for (var c = 1; c <= lastCol; c++) {
    sheet.setColumnWidth(c, 9);
  }

  final labelsByRow = <Set<int>>[
    for (final t in data.tasks) ProcessScheduleEditor.labelCenterDayIndices(t),
  ];

  /// 본문: 배경 블렌드 + 채워진 칸은 앱처럼 막대 원색 기준 흑/백. 일반 일정 칸은 앱처럼 텍스트 없이 배경만.
  CellStyle gridCellStyle({
    required ExcelColor bg,
    required ExcelColor fg,
    required double fontSize,
    required bool bold,
  }) =>
      CellStyle(
        fontColorHex: fg,
        backgroundColorHex: bg,
        fontSize: fontSize.round(),
        bold: bold,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        topBorder: _thinGrid(),
        bottomBorder: _thinGrid(),
        leftBorder: _thinGrid(),
        rightBorder: _thinGrid(),
      );

  for (var ti = 0; ti < data.tasks.length; ti++) {
    final row = headerRow + 1 + ti;
    final t = data.tasks[ti];
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      TextCellValue(t.name),
      cellStyle: CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.black,
        backgroundColorHex: ExcelColor.grey200,
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        leftBorder: _thinGrid(),
        topBorder: _thinGrid(),
        bottomBorder: _thinGrid(),
        rightBorder: _thinGrid(),
      ),
    );

    final labelCells = labelsByRow[ti];
    for (var di = 0; di < data.dayCount; di++) {
      final on = t.scheduledDayIndices.contains(di);
      final CellValue cv;
      if (!on) {
        cv = TextCellValue('');
      } else if (labelCells.contains(di)) {
        cv = TextCellValue(_ellipsis(t.name, 18));
      } else {
        cv = TextCellValue('');
      }

      final isCenterLabel = on && labelCells.contains(di);

      final bg = _excelBg(t, on);

      late final ExcelColor fg;
      if (!on) {
        fg = ExcelColor.grey900;
      } else if (isCenterLabel) {
        fg = _excelFgOnBar(t);
      } else {
        fg = ExcelColor.grey900;
      }

      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: di + 1, rowIndex: row),
        cv,
        cellStyle: gridCellStyle(
          bg: bg,
          fg: fg,
          fontSize: isCenterLabel ? 9 : 10,
          bold: isCenterLabel,
        ),
      );
    }
  }

  sheet.setRowHeight(headerRow, 24);

  final raw = excel.encode();
  if (raw == null) return null;

  // A열(구분) + 5행(날짜 헤더) 고정 — 가로·세로 스크롤 시에도 기준선 유지.
  const frozenRows = headerRow + 1; // Excel 1-based: 5행까지
  return applyXlsxFreezePanes(
    Uint8List.fromList(raw),
    frozenRows: frozenRows,
    frozenColumns: 1,
  );
}
