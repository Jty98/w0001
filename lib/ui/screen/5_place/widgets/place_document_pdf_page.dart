import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// PDF 원본 보기 + 인쇄·공유·파일명 복사.
class PlaceDocumentPdfPage extends StatelessWidget {
  const PlaceDocumentPdfPage({
    super.key,
    required this.bytes,
    required this.displayName,
  });

  final Uint8List bytes;
  final String displayName;

  Future<void> _print() async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _share() async {
    final dir = await getTemporaryDirectory();
    var name = displayName.replaceAll(RegExp(r'[/\\:?*"<>|]'), '_').trim();
    if (name.isEmpty) name = 'document.pdf';
    if (!name.toLowerCase().endsWith('.pdf')) {
      name = '$name.pdf';
    }
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path)]),
    );
  }

  void _copyFileName(BuildContext context) {
    Clipboard.setData(ClipboardData(text: displayName));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('파일 이름을 클립보드에 복사했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '파일명 복사',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () => _copyFileName(context),
          ),
          IconButton(
            tooltip: '다른 앱으로 공유',
            icon: const Icon(Icons.share_outlined),
            onPressed: _share,
          ),
          IconButton(
            tooltip: '인쇄',
            icon: const Icon(Icons.print_outlined),
            onPressed: _print,
          ),
        ],
      ),
      body: PdfViewer.data(
        bytes,
        sourceName: displayName,
      ),
    );
  }
}
