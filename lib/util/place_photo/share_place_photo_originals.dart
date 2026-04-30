import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/place_photo_entry.dart';
import 'package:w0001/util/place_photo/place_photo_original_api.dart';

String _sanitizeFileName(String name) {
  var s =
      name.replaceAll(RegExp(r'[/\\:?*"<>|\s]+'), '_').trim();
  if (s.isEmpty) s = 'image';
  if (s.length > 160) {
    final extMatch = RegExp(r'(\.[a-zA-Z0-9]{1,12})$').firstMatch(s);
    final ext = extMatch?.group(1) ?? '';
    final base = ext.isNotEmpty
        ? s.substring(0, s.length - ext.length)
        : s;
    s = '${base.substring(0, base.length.clamp(0, 140))}$ext';
  }
  return s;
}

Future<void> sharePlacePhotoOriginalEntries(
  BuildContext context,
  List<PlacePhotoEntry> entries,
) async {
  final ms = ScaffoldMessenger.maybeOf(context);
  void tip(String msg) {
    ms?.hideCurrentSnackBar();
    ms?.showSnackBar(SnackBar(content: Text(msg)));
  }

  final list = entries.where((e) => e.canFetchOriginalViaApi).toList();
  if (list.isEmpty) {
    tip('공유 가능한 사진이 없습니다. (서버에 등록된 사진만 가능)');
    return;
  }

  tip('사진 받는 중…');
  final tmp = await getTemporaryDirectory();
  final files = <XFile>[];

  try {
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      final payload = await fetchPlacePhotoOriginalFile(e.phid, inline: false);
      final fromHeader = payload.filenameSuggestion;
      final rawName =
          (fromHeader != null && fromHeader.trim().isNotEmpty)
              ? p.basename(fromHeader.trim())
              : (e.originalName ?? '').trim();
      final fallbackName = rawName.isNotEmpty ? rawName : 'place_${e.phid}';
      var base = _sanitizeFileName(fallbackName);
      if (p.extension(base).isEmpty) {
        base = '$base.bin';
      }
      final path = p.join(tmp.path, 'share_phid_${e.phid}_${i}_$base');
      final f = File(path);
      await f.writeAsBytes(payload.bytes, flush: true);
      files.add(XFile(f.path));
    }

    ms?.hideCurrentSnackBar();
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        subject:
            list.length == 1 ? '현장 사진' : '현장 사진 (${list.length}장)',
        text: list.length == 1
            ? '현장 사진'
            : '현장 사진 ${list.length}장',
      ),
    );
  } on HttpClientException catch (e) {
    ms?.hideCurrentSnackBar();
    tip(e.message);
  } catch (e) {
    ms?.hideCurrentSnackBar();
    tip('공유 준비에 실패했습니다: $e');
  }
}
