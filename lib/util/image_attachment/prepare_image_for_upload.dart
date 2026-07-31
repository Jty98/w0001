import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 서버 `IMAGE_DISPLAY_MAX_LONG_EDGE` 와 맞춤.
const int kUploadImageMaxLongEdge = 1920;

/// JPEG 업로드 품질 — 서버 `IMAGE_WEBP_QUALITY` 82 근처.
const int kUploadImageJpegQuality = 85;

bool shouldPreprocessImageForUpload(String absolutePath) {
  switch (p.extension(absolutePath).toLowerCase()) {
    case '.jpg':
    case '.jpeg':
    case '.png':
    case '.heic':
    case '.heif':
    case '.webp':
      return true;
    default:
      return false;
  }
}

/// 카메라·갤러리 원본을 업로드용 JPEG로 리사이즈한다. 실패 시 [absolutePath] 그대로.
Future<String> prepareImageFileForUpload(String absolutePath) async {
  if (!shouldPreprocessImageForUpload(absolutePath)) {
    return absolutePath;
  }
  final source = File(absolutePath);
  if (!await source.exists()) return absolutePath;

  try {
    final tmp = await getTemporaryDirectory();
    final base = p.basenameWithoutExtension(absolutePath);
    final outPath = p.join(
      tmp.path,
      'upload_${DateTime.now().millisecondsSinceEpoch}_$base.jpg',
    );
    final compressed = await FlutterImageCompress.compressAndGetFile(
      absolutePath,
      outPath,
      minWidth: kUploadImageMaxLongEdge,
      minHeight: kUploadImageMaxLongEdge,
      quality: kUploadImageJpegQuality,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (compressed == null) return absolutePath;
    final out = File(compressed.path);
    if (!await out.exists()) return absolutePath;
    return compressed.path;
  } catch (e, st) {
    debugPrint('prepareImageFileForUpload failed: $e\n$st');
    return absolutePath;
  }
}
