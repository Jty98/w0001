import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

String? mimeTypeForDocumentExtension(String extension) {
  switch (extension.toLowerCase()) {
    case '.pdf':
      return 'application/pdf';
    case '.xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case '.xls':
      return 'application/vnd.ms-excel';
    default:
      return null;
  }
}

String shareableDocumentFileName(String displayName, String extension) {
  var base =
      p.basename(displayName).replaceAll(RegExp(r'[/\\:?*"<>|]'), '_').trim();
  if (base.isEmpty) base = 'document';
  final ext = extension.toLowerCase();
  if (!base.toLowerCase().endsWith(ext)) {
    base = '$base$ext';
  }
  return base;
}

Future<String> writeDocumentBytesToTempFile(
  Uint8List bytes,
  String displayName, {
  required String extension,
}) async {
  final dir = await getTemporaryDirectory();
  final path = p.join(
    dir.path,
    'open_${DateTime.now().millisecondsSinceEpoch}_${shareableDocumentFileName(displayName, extension)}',
  );
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

String? _utiForExtension(String ext) {
  switch (ext) {
    case '.xlsx':
      return 'org.openxmlformats.spreadsheetml.sheet';
    case '.xls':
      return 'com.microsoft.excel.xls';
    case '.pdf':
      return 'com.adobe.pdf';
    default:
      return null;
  }
}

/// Android 등에서 기본 앱으로 연다. iOS xlsx는 인앱 갤러리 시트를 쓴다.
Future<bool> tryOpenDocumentBytesExternally(
  Uint8List bytes,
  String displayName, {
  required String extension,
}) async {
  if (Platform.isIOS) return false;
  try {
    final path = await writeDocumentBytesToTempFile(
      bytes,
      displayName,
      extension: extension,
    );
    final ext = extension.toLowerCase();
    final r = await OpenFilex.open(
      path,
      type: mimeTypeForDocumentExtension(ext),
      uti: _utiForExtension(ext),
    );
    return r.type == ResultType.done;
  } catch (_) {
    return false;
  }
}
