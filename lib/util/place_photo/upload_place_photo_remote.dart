import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/util/api_endpoint.dart';
import 'package:w0001/util/image_attachment/image_upload_result.dart';

/// PDF·엑셀 등은 [`POST /uploads/image`] 가 아니라 [`POST /place-photos/upload`] 로 올린다.
bool shouldUsePlacePhotoMultipartUpload(String absolutePath) {
  final e = absolutePath.toLowerCase();
  return e.endsWith('.pdf') || e.endsWith('.xlsx') || e.endsWith('.xls');
}

MediaType? _placePhotoUploadMultipartMediaType(String absolutePath) {
  switch (p.extension(absolutePath).toLowerCase()) {
    case '.pdf':
      return MediaType('application', 'pdf');
    case '.xlsx':
      return MediaType(
        'application',
        'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    case '.xls':
      return MediaType('application', 'vnd.ms-excel');
    default:
      return null;
  }
}

/// `multipart/form-data`: `file`, `pid`, `pgid`, `photo_type`, `photodate`, `sortorder`, 선택 `memo`.
///
/// 서버가 `PlacePhoto` 행까지 생성하면 응답에 `phid` 가 있고 [ImageUploadResult.skipPlacePhotoCreate] 가 true.
Future<ImageUploadResult> uploadLocalPlacePhotoMultipart({
  required String absolutePath,
  required int pid,
  required int pgid,
  required String photoType,
  required String photoDate,
  required int sortOrder,
  String memo = '',
}) async {
  final file = File(absolutePath);
  if (!await file.exists()) {
    throw ArgumentError.value(absolutePath, 'absolutePath', '파일이 없습니다.');
  }
  final dio = AppHttpClient.I.raw;
  final uploadName = ImageUploadResult.guessOriginalnameFallback(absolutePath);
  final multipart = await MultipartFile.fromFile(
    absolutePath,
    filename: uploadName.isNotEmpty ? uploadName : 'upload.bin',
    contentType: _placePhotoUploadMultipartMediaType(absolutePath),
  );
  final form = FormData.fromMap(<String, dynamic>{
    'file': multipart,
    'pid': pid,
    'pgid': pgid,
    'photo_type': photoType,
    'phototype': photoType,
    'photodate': photoDate,
    'sortorder': sortOrder,
    if (memo.trim().isNotEmpty) 'memo': memo.trim(),
  });
  try {
    final res = await dio.post<dynamic>(
      ApiEndpoint.placePhotosUpload,
      data: form,
    );
    dynamic body = res.data;
    if (body is List && body.isNotEmpty && body.first is Map) {
      body = body.first;
    }
    if (body is! Map) {
      throw StateError(
        'place-photos/upload 응답 형식 오류 (${body.runtimeType})',
      );
    }
    return ImageUploadResult.fromPlacePhotoUploadResponse(
      Map<String, dynamic>.from(body),
    );
  } on DioException catch (e) {
    throw e.error ?? e;
  }
}
