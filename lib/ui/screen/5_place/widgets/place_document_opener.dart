import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:w0001/data/model/place_photo_entry.dart';
import 'package:w0001/navigation/app_router.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_document_excel_gallery_sheet.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_document_pdf_page.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_document_viewer_route.dart';
import 'package:w0001/util/place_photo/place_document_classify.dart';
import 'package:w0001/util/place_photo/place_document_file_open.dart';
import 'package:w0001/util/place_photo/place_photo_original_api.dart';

BuildContext? _documentHostContext([BuildContext? fallback]) {
  final root = rootNavigatorKey.currentContext;
  if (root != null && root.mounted) return root;
  if (fallback != null && fallback.mounted) {
    return Navigator.of(fallback, rootNavigator: true).context;
  }
  return null;
}

Future<T?> _pushPlaceDocumentPage<T>(
  BuildContext? context,
  Widget page, {
  bool fullscreenDialog = true,
}) {
  final host = _documentHostContext(context);
  if (host == null) return Future.value(null);
  if (!fullscreenDialog) {
    return Navigator.of(host, rootNavigator: true).push<T>(
      MaterialPageRoute<T>(
        fullscreenDialog: false,
        builder: (_) => page,
      ),
    );
  }
  return Navigator.of(host, rootNavigator: true).push<T>(
    PlaceDocumentViewerRoute<T>(childBuilder: (_) => page),
  );
}

PlaceDocumentKind _resolveDocumentKind({
  required PlacePhotoEntry entry,
  required Uint8List bytes,
  required String fileName,
  String? contentType,
}) {
  final hint = classifyPlaceDocumentForViewer(entry);
  var kind = classifyPlaceDocument(
    bytes: bytes,
    fileName: fileName,
    contentType: contentType,
  );
  if (kind == PlaceDocumentKind.imageOrOther &&
      hint != PlaceDocumentKind.imageOrOther) {
    kind = hint;
  }
  if (kind != PlaceDocumentKind.imageOrOther) return kind;
  if (!entry.isDocumentMedia) return kind;
  if (looksPdfMagic(bytes)) return PlaceDocumentKind.pdf;
  if (looksZipMagic(bytes)) return PlaceDocumentKind.spreadsheetXlsx;
  if (looksOleCompoundMagic(bytes)) return PlaceDocumentKind.legacyXls;
  return kind;
}

/// 원본을 받아 PDF는 앱 뷰어, xlsx는 iOS 인앱·Android 외부 앱으로 연다.
Future<void> openPlacePhotoOriginalDocument(
  BuildContext context, {
  required PlacePhotoEntry entry,
}) async {
  final host = _documentHostContext(context);
  if (host == null) return;

  if (!entry.canFetchOriginalViaApi) {
    ScaffoldMessenger.of(host).showSnackBar(
      const SnackBar(content: Text('서버에 등록된 문서만 열 수 있습니다.')),
    );
    return;
  }

  showDialog<void>(
    context: host,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => const PopScope(
      canPop: false,
      child: Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLoadingIndicator(size: 68),
                SizedBox(height: 16),
                Text('원본 문서를 불러오는 중…'),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  final rootNav = Navigator.of(host, rootNavigator: true);
  try {
    final payload = await fetchPlacePhotoOriginalFile(entry.phid);
    if (rootNav.mounted) {
      rootNav.pop();
    }

    final name = resolvedDocumentDisplayName(
      originalName: entry.originalName,
      contentDispositionName: payload.filenameSuggestion,
      originalUrl: entry.originalUrl,
      displayUrl: entry.displayUrl,
      phid: entry.phid,
    );
    final kind = _resolveDocumentKind(
      entry: entry,
      bytes: payload.bytes,
      fileName: name,
      contentType: payload.contentType,
    );

    switch (kind) {
      case PlaceDocumentKind.pdf:
        await _pushPlaceDocumentPage<void>(
          host,
          PlaceDocumentPdfPage(
            bytes: payload.bytes,
            displayName: name,
          ),
        );
        return;
      case PlaceDocumentKind.spreadsheetXlsx:
        if (Platform.isAndroid) {
          final opened = await tryOpenDocumentBytesExternally(
            payload.bytes,
            name,
            extension: '.xlsx',
          );
          if (opened) return;
        }
        await showPlaceDocumentExcelGallerySheet(
          host,
          bytes: payload.bytes,
          displayName: name,
        );
        return;
      case PlaceDocumentKind.legacyXls:
        if (Platform.isAndroid) {
          final openedXls = await tryOpenDocumentBytesExternally(
            payload.bytes,
            name,
            extension: '.xls',
          );
          if (openedXls) return;
        }
        await _offerLegacyXlsShare(host, payload.bytes, name);
        return;
      case PlaceDocumentKind.imageOrOther:
        ScaffoldMessenger.of(host).showSnackBar(
          const SnackBar(
            content: Text(
              '이 파일은 앱에서 표 형식·PDF로 열 수 없습니다. 이미지 보기·공유를 이용해 주세요.',
            ),
          ),
        );
        return;
    }
  } catch (e) {
    if (rootNav.mounted && rootNav.canPop()) {
      rootNav.pop();
    }
    ScaffoldMessenger.of(host).showSnackBar(
      SnackBar(content: Text('문서를 불러오지 못했습니다: $e')),
    );
  }
}

Future<void> _offerLegacyXlsShare(
  BuildContext context,
  Uint8List bytes,
  String displayName,
) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: const Text('Excel 97–2003 (.xls)'),
      content: const Text(
        '이 형식은 앱 안에서 표 미리보기를 지원하지 않습니다. '
        '다른 앱으로 열거나 인쇄하려면 아래에서 파일을 공유해 주세요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: () async {
            final tmp = await getTemporaryDirectory();
            var base = p.basename(displayName);
            if (!base.toLowerCase().endsWith('.xls')) {
              base = '$base.xls';
            }
            final f = File(p.join(
                tmp.path, base.replaceAll(RegExp(r'[/\\:?*"<>|]'), '_')));
            await f.writeAsBytes(bytes, flush: true);
            if (ctx.mounted) Navigator.pop(ctx);
            await SharePlus.instance.share(
              ShareParams(files: [XFile(f.path)]),
            );
          },
          child: const Text('파일 공유'),
        ),
      ],
    ),
  );
}
