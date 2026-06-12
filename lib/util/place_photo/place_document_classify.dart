import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:w0001/data/model/place_photo_entry.dart';

/// 서버 원본 바이트·파일명 기준 문서 종류(뷰어·인쇄 분기).
enum PlaceDocumentKind {
  pdf,
  spreadsheetXlsx,
  legacyXls,
  imageOrOther,
}

bool _looksPdfMagic(Uint8List bytes) =>
    bytes.length >= 5 &&
    bytes[0] == 0x25 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x44 &&
    bytes[3] == 0x46;

bool _looksZipMagic(Uint8List bytes) =>
    bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;

bool _looksOleCompoundMagic(Uint8List bytes) =>
    bytes.length >= 8 &&
    bytes[0] == 0xD0 &&
    bytes[1] == 0xCF &&
    bytes[2] == 0x11 &&
    bytes[3] == 0xE0;

String _lowerName(String? name) => (name ?? '').trim().toLowerCase();

/// 파일명 힌트만으로(원본 받기 전) 썸네일·버튼 노출용.
PlaceDocumentKind classifyPlaceDocumentByFileName(String? originalName) {
  final n = _lowerName(originalName);
  if (n.endsWith('.pdf')) return PlaceDocumentKind.pdf;
  if (n.endsWith('.xlsx')) return PlaceDocumentKind.spreadsheetXlsx;
  if (n.endsWith('.xls')) return PlaceDocumentKind.legacyXls;
  return PlaceDocumentKind.imageOrOther;
}

/// 리스트·전체화면 등 [PlacePhotoEntry] 기준 — `originalname`이 비면 [PlacePhotoEntry.displayUrl] 힌트 사용.
PlaceDocumentKind classifyPlaceDocumentForViewer(PlacePhotoEntry e) {
  final k = classifyPlaceDocumentByFileName(e.originalName);
  if (k != PlaceDocumentKind.imageOrOther) return k;
  final u = e.displayUrl.toLowerCase();
  if (u.endsWith('.pdf') || u.contains('.pdf?')) {
    return PlaceDocumentKind.pdf;
  }
  if (u.endsWith('.xlsx') || u.contains('.xlsx?')) {
    return PlaceDocumentKind.spreadsheetXlsx;
  }
  if (u.endsWith('.xls') || u.contains('.xls?')) {
    return PlaceDocumentKind.legacyXls;
  }
  return PlaceDocumentKind.imageOrOther;
}

PlaceDocumentKind classifyPlaceDocument({
  required Uint8List bytes,
  required String fileName,
}) {
  final n = _lowerName(fileName);
  if (_looksPdfMagic(bytes) || n.endsWith('.pdf')) {
    return PlaceDocumentKind.pdf;
  }
  final tryModernExcel =
      n.endsWith('.xlsx') || n.endsWith('.xls') || _looksZipMagic(bytes);
  if (tryModernExcel && _canDecodeAsXlsx(bytes)) {
    return PlaceDocumentKind.spreadsheetXlsx;
  }
  if (n.endsWith('.xls') || _looksOleCompoundMagic(bytes)) {
    return PlaceDocumentKind.legacyXls;
  }
  if (n.endsWith('.xlsx')) {
    return PlaceDocumentKind.spreadsheetXlsx;
  }
  return PlaceDocumentKind.imageOrOther;
}

bool _canDecodeAsXlsx(Uint8List bytes) {
  try {
    Excel.decodeBytes(bytes);
    return true;
  } catch (_) {
    try {
      SpreadsheetDecoder.decodeBytes(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }
}

String resolvedDocumentDisplayName({
  required String? originalName,
  required String? contentDispositionName,
  int? phid,
}) {
  final fromCd = contentDispositionName?.trim();
  if (fromCd != null && fromCd.isNotEmpty) return fromCd;
  final on = originalName?.trim();
  if (on != null && on.isNotEmpty) return on;
  if (phid != null && phid > 0) return 'place_$phid';
  return 'document';
}
