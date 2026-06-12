import 'dart:io';

import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/util/api_endpoint.dart';
import 'package:w0001/util/image_attachment/image_upload_result.dart';

/// 기기 로컬 이미지를 [`POST /uploads/image`](`multipart/form-data`,
/// 필드 `file` + 선택 `category`)로 올리고 메타를 돌려준다.
///
/// [category]: `place_image` | `plan_image` | `announcement_image`
/// (생략 시 서버 기본과 동일하게 [ImageUploadCategory.placeImage]).
///
/// Bearer 토큰은 [AppHttpClient] 인터셉터와 동일하게 붙는다.
Future<ImageUploadResult> uploadLocalImageFile(
  String absolutePath, {
  ImageUploadCategory category = ImageUploadCategory.placeImage,
}) async {
  final file = File(absolutePath);
  if (!await file.exists()) {
    throw ArgumentError.value(absolutePath, 'absolutePath', '파일이 없습니다.');
  }
  final dio = AppHttpClient.I.raw;
  // [MultipartFile.fromFile] 은 Future — await 하지 않으면 FormData 가 이를 파일이 아니라
  // 문자열 필드(Instance of 'Future<MultipartFile>' …) 로 보내 서버는 str 로 받게 된다.
  final multipart = await MultipartFile.fromFile(
    absolutePath,
    filename: ImageUploadResult.guessOriginalnameFallback(absolutePath),
  );
  final form = FormData.fromMap(<String, dynamic>{
    'file': multipart,
    'category': category.serverValue,
  });
  try {
    final res = await dio.post<dynamic>(
      ApiEndpoint.uploadsImage,
      data: form,
      // Dio가 FormData 의 boundary 포함 Content-Type 을 설정한다.
    );
    final body = res.data;
    if (body is! Map) {
      throw StateError(
        'uploads/image 응답 형식 오류 (${body.runtimeType})',
      );
    }
    return ImageUploadResult.fromJson(Map<String, dynamic>.from(body));
  } on DioException catch (e) {
    throw e.error ?? e;
  }
}
