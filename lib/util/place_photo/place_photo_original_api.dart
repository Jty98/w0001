import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/util/api_endpoint.dart';

/// `GET /place-photos/{phid}/original-file` 로 디스크 원본 바이트.
///
/// Bearer 는 [AppHttpClient] 인터셉터와 동일.
Future<PlacePhotoOriginalPayload> fetchPlacePhotoOriginalFile(
  int phid, {
  bool inline = false,
}) async {
  if (phid <= 0) {
    throw ArgumentError.value(phid, 'phid', '유효한 phid 가 아닙니다.');
  }
  final dio = AppHttpClient.I.raw;
  try {
    final res = await dio.get<dynamic>(
      ApiEndpoint.placePhotosOriginalFile(phid),
      queryParameters: inline ? <String, dynamic>{'inline': 'true'} : null,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
      ),
    );
    final data = res.data;
    Uint8List bytes;
    if (data is Uint8List) {
      bytes = data;
    } else if (data is List<int>) {
      bytes = Uint8List.fromList(data);
    } else {
      throw StateError('원본 응답 바이트 형식 오류(${data.runtimeType})');
    }
    final disposition = res.headers.map['content-disposition']?.join();
    final contentType = res.headers.map['content-type']?.join();
    final filenameHint = disposition != null
        ? filenameFromContentDisposition(disposition)
        : null;
    return PlacePhotoOriginalPayload(
      bytes: bytes,
      filenameSuggestion: filenameHint,
      contentType: contentType,
    );
  } on DioException catch (e) {
    throw e.error ?? e;
  }
}

class PlacePhotoOriginalPayload {
  PlacePhotoOriginalPayload({
    required this.bytes,
    this.filenameSuggestion,
    this.contentType,
  });

  final Uint8List bytes;

  /// `Content-Disposition` 에서 파싱했을 때만.
  final String? filenameSuggestion;

  /// `Content-Type` 헤더 (문서 종류 판별 보조).
  final String? contentType;
}

String? filenameFromContentDisposition(String? header) {
  if (header == null || header.isEmpty) return null;
  final star = RegExp(r"filename\*=UTF-8''([^;\r\n]+)", caseSensitive: false)
      .firstMatch(header)
      ?.group(1);
  if (star != null && star.isNotEmpty) {
    return Uri.decodeComponent(star);
  }
  final fname =
      RegExp(r'''filename=(?:"([^"]+)"|([^;\r\n]+))''', caseSensitive: false)
          .firstMatch(header);
  if (fname != null) {
    final quoted = fname.group(1);
    final unquoted = fname.group(2);
    final s = quoted ?? (unquoted?.trim()) ?? '';
    if (s.isNotEmpty) return s.trim();
  }
  return null;
}
