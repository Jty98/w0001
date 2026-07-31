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

bool looksPdfMagic(Uint8List bytes) =>
    bytes.length >= 5 &&
    bytes[0] == 0x25 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x44 &&
    bytes[3] == 0x46;

bool looksZipMagic(Uint8List bytes) =>
    bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;

bool looksOleCompoundMagic(Uint8List bytes) =>
    bytes.length >= 8 &&
    bytes[0] == 0xD0 &&
    bytes[1] == 0xCF &&
    bytes[2] == 0x11 &&
    bytes[3] == 0xE0;

String _lowerName(String? name) => (name ?? '').trim().toLowerCase();

/// URL 경로에서 파일명(확장자) 힌트.
String? fileNameHintFromUrl(String? url) {
  final raw = url?.trim();
  if (raw == null || raw.isEmpty) return null;
  try {
    final uri = Uri.parse(raw);
    final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    if (seg.isEmpty) return null;
    return Uri.decodeComponent(seg.split('?').first);
  } catch (_) {
    final slash = raw.lastIndexOf('/');
    final tail = slash >= 0 ? raw.substring(slash + 1) : raw;
    final clean = tail.split('?').first.trim();
    return clean.isEmpty ? null : clean;
  }
}

PlaceDocumentKind? _classifyByContentType(String? contentType) {
  final ct = _lowerName(contentType);
  if (ct.isEmpty) return null;
  if (ct.contains('pdf')) return PlaceDocumentKind.pdf;
  if (ct.contains('ms-excel') && !ct.contains('openxml')) {
    return PlaceDocumentKind.legacyXls;
  }
  if (ct.contains('spreadsheet') ||
      ct.contains('excel') ||
      ct.contains('sheet')) {
    return PlaceDocumentKind.spreadsheetXlsx;
  }
  return null;
}

/// 파일명 힌트만으로(원본 받기 전) 썸네일·버튼 노출용.
PlaceDocumentKind classifyPlaceDocumentByFileName(String? originalName) {
  final n = _lowerName(originalName);
  if (n.endsWith('.pdf')) return PlaceDocumentKind.pdf;
  if (n.endsWith('.xlsx')) return PlaceDocumentKind.spreadsheetXlsx;
  if (n.endsWith('.xls')) return PlaceDocumentKind.legacyXls;
  final placeholder = _classifyPlaceholderAsset(n);
  if (placeholder != null) return placeholder;
  return PlaceDocumentKind.imageOrOther;
}

/// 서버 `display_url` 플레이스홀더 (`…/placeholders/plan-document-pdf.svg` 등).
PlaceDocumentKind? _classifyPlaceholderAsset(String? value) {
  final v = (value ?? '').trim().toLowerCase();
  if (v.isEmpty) return null;
  if (v.contains('document-pdf') ||
      v.contains('-pdf.') ||
      v.contains('_pdf.')) {
    return PlaceDocumentKind.pdf;
  }
  if (v.contains('document-sheet') ||
      v.contains('-sheet.') ||
      v.contains('_sheet.')) {
    return PlaceDocumentKind.spreadsheetXlsx;
  }
  if (v.contains('document-xlsx') ||
      v.contains('document-excel') ||
      v.contains('-xlsx.') ||
      v.contains('-excel.')) {
    return PlaceDocumentKind.spreadsheetXlsx;
  }
  if (v.contains('document-xls') || v.contains('-xls.')) {
    return PlaceDocumentKind.legacyXls;
  }
  if (!v.contains('placeholder')) return null;
  if (v.contains('pdf')) return PlaceDocumentKind.pdf;
  if (v.contains('sheet') ||
      v.contains('xlsx') ||
      v.contains('excel') ||
      v.contains('spreadsheet')) {
    return PlaceDocumentKind.spreadsheetXlsx;
  }
  if (v.contains('xls')) return PlaceDocumentKind.legacyXls;
  return null;
}

PlaceDocumentKind _classifyByUrlHints(String url) {
  final placeholder = _classifyPlaceholderAsset(url);
  if (placeholder != null) return placeholder;
  final u = url.toLowerCase();
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

/// 원본 API(`GET …/original-file`)로 인앱 뷰어를 열 수 있는지(메타·플레이스홀더 기준).
bool shouldOfferInAppDocumentViewer(PlacePhotoEntry e) {
  return isPlacePhotoDocumentEntry(e);
}

/// 문서(PDF·엑셀 등) 항목인지 — 갤러리·전체화면 분기용.
bool isPlacePhotoDocumentEntry(PlacePhotoEntry e) {
  if (!e.canFetchOriginalViaApi) return false;
  if (e.isDocumentMedia) return true;
  return classifyPlaceDocumentForViewer(e) != PlaceDocumentKind.imageOrOther;
}

/// 리스트·전체화면 등 [PlacePhotoEntry] 기준.
PlaceDocumentKind classifyPlaceDocumentForViewer(PlacePhotoEntry e) {
  for (final source in [e.displayUrl, e.originalUrl]) {
    final ph = _classifyPlaceholderAsset(source);
    if (ph != null) return ph;
  }
  for (final hint in [
    e.originalName,
    fileNameHintFromUrl(e.originalUrl),
    fileNameHintFromUrl(e.displayUrl),
  ]) {
    final k = classifyPlaceDocumentByFileName(hint);
    if (k != PlaceDocumentKind.imageOrOther) return k;
  }
  return _classifyByUrlHints(e.displayUrl);
}

PlaceDocumentKind classifyPlaceDocument({
  required Uint8List bytes,
  required String fileName,
  String? contentType,
}) {
  final fromCt = _classifyByContentType(contentType);
  if (fromCt != null) return fromCt;

  final n = _lowerName(fileName);
  if (looksPdfMagic(bytes) || n.endsWith('.pdf')) {
    return PlaceDocumentKind.pdf;
  }
  final tryModernExcel =
      n.endsWith('.xlsx') || n.endsWith('.xls') || looksZipMagic(bytes);
  if (tryModernExcel && _canDecodeAsXlsx(bytes)) {
    return PlaceDocumentKind.spreadsheetXlsx;
  }
  if (n.endsWith('.xls') || looksOleCompoundMagic(bytes)) {
    return PlaceDocumentKind.legacyXls;
  }
  if (n.endsWith('.xlsx')) {
    return PlaceDocumentKind.spreadsheetXlsx;
  }
  if (looksPdfMagic(bytes)) return PlaceDocumentKind.pdf;
  if (looksZipMagic(bytes) && _canDecodeAsXlsx(bytes)) {
    return PlaceDocumentKind.spreadsheetXlsx;
  }
  if (looksOleCompoundMagic(bytes)) return PlaceDocumentKind.legacyXls;
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
  String? originalUrl,
  String? displayUrl,
  int? phid,
}) {
  final fromCd = contentDispositionName?.trim();
  if (fromCd != null && fromCd.isNotEmpty) return fromCd;
  final on = originalName?.trim();
  if (on != null && on.isNotEmpty) return on;
  for (final url in [originalUrl, displayUrl]) {
    final fromUrl = fileNameHintFromUrl(url)?.trim();
    if (fromUrl == null || fromUrl.isEmpty) continue;
    final ph = _classifyPlaceholderAsset(fromUrl);
    if (ph == PlaceDocumentKind.pdf) return 'document.pdf';
    if (ph == PlaceDocumentKind.spreadsheetXlsx) return 'document.xlsx';
    if (ph == PlaceDocumentKind.legacyXls) return 'document.xls';
    return fromUrl;
  }
  if (phid != null && phid > 0) return 'place_$phid';
  return 'document';
}
