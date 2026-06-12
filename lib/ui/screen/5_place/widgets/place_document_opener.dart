import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:w0001/data/model/place_photo_entry.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_document_excel_page.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_document_pdf_page.dart';
import 'package:w0001/util/place_photo/place_document_classify.dart';
import 'package:w0001/util/place_photo/place_photo_original_api.dart';

/// 하단 메인 탭바 위에 전체 화면으로 문서 뷰어를 연다.
///
/// [fullscreenDialog]가 true이면 iOS 등에서 아래로 드래그해 닫을 수 있는 모달로
/// 뜬다. 엑셀 표는 세로·가로 스크롤이 많아 실수로 닫히지 않도록 false를 쓴다.
Future<T?> _pushPlaceDocumentPage<T>(
  BuildContext context,
  Widget page, {
  bool fullscreenDialog = true,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute<T>(
      fullscreenDialog: fullscreenDialog,
      builder: (_) => page,
    ),
  );
}

/// 원본을 받아 PDF는 인앱 뷰어, xlsx·xls는 기본 앱으로 우선 열고
/// (실패 시에만 xlsx는 인앱 표·xls는 공유 안내).
Future<void> openPlacePhotoOriginalDocument(
  BuildContext context, {
  required PlacePhotoEntry entry,
}) async {
  if (!entry.canFetchOriginalViaApi) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('서버에 등록된 문서만 열 수 있습니다.')),
    );
    return;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const PopScope(
      canPop: false,
      child: Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('원본 문서를 불러오는 중…'),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  final rootNav = Navigator.of(context, rootNavigator: true);
  try {
    final payload = await fetchPlacePhotoOriginalFile(entry.phid);
    if (rootNav.mounted) {
      rootNav.pop();
    }
    if (!context.mounted) return;

    final name = resolvedDocumentDisplayName(
      originalName: entry.originalName,
      contentDispositionName: payload.filenameSuggestion,
      phid: entry.phid,
    );
    final kind = classifyPlaceDocument(bytes: payload.bytes, fileName: name);

    switch (kind) {
      case PlaceDocumentKind.pdf:
        await _pushPlaceDocumentPage<void>(
          context,
          PlaceDocumentPdfPage(
            bytes: payload.bytes,
            displayName: name,
          ),
        );
        return;
      case PlaceDocumentKind.spreadsheetXlsx:
        final openedXlsx = await tryOpenDocumentBytesExternally(
          payload.bytes,
          name,
          extension: '.xlsx',
        );
        if (!context.mounted) return;
        if (!openedXlsx) {
          await _pushPlaceDocumentPage<void>(
            context,
            PlaceDocumentExcelPage(
              bytes: payload.bytes,
              displayName: name,
            ),
            fullscreenDialog: false,
          );
        }
        return;
      case PlaceDocumentKind.legacyXls:
        final openedXls = await tryOpenDocumentBytesExternally(
          payload.bytes,
          name,
          extension: '.xls',
        );
        if (!context.mounted) return;
        if (!openedXls) {
          await _offerLegacyXlsShare(context, payload.bytes, name);
        }
        return;
      case PlaceDocumentKind.imageOrOther:
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('문서를 불러오지 못했습니다: $e')),
      );
    }
  }
}

/// xlsx/xls를 기기 기본 앱으로 연다. 실패 시 `false`.
Future<bool> tryOpenDocumentBytesExternally(
  Uint8List bytes,
  String displayName, {
  required String extension,
}) async {
  try {
    final dir = await getTemporaryDirectory();
    var base =
        p.basename(displayName).replaceAll(RegExp(r'[/\\:?*"<>|]'), '_').trim();
    if (base.isEmpty) base = 'document$extension';
    final lower = base.toLowerCase();
    if (!lower.endsWith(extension.toLowerCase())) {
      base = '$base$extension';
    }
    final path = p.join(
      dir.path,
      'open_${DateTime.now().millisecondsSinceEpoch}_$base',
    );
    await File(path).writeAsBytes(bytes, flush: true);
    final r = await OpenFilex.open(path);
    return r.type == ResultType.done;
  } catch (_) {
    return false;
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
            final f = File(p.join(tmp.path, base.replaceAll(RegExp(r'[/\\:?*"<>|]'), '_')));
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
