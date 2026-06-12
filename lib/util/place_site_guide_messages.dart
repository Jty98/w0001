import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/util/auth_api_user_messages.dart';

String placeSiteGuideUserMessage(Object error, {required String fallback}) {
  if (error is HttpStatusException) {
    if (error.statusCode == 403) {
      return '이 현장에 접근할 수 없습니다.';
    }
    final fromBody = localizedAuthDetailMessage(
      httpStatusCode: error.statusCode,
      responseData: error.body,
    );
    if (fromBody.trim().isNotEmpty) return fromBody;
    return error.message;
  }
  if (error is DioException) {
    final err = error.error;
    if (err is HttpStatusException) {
      return placeSiteGuideUserMessage(err, fallback: fallback);
    }
    if (err is HttpConnectionException) return err.message;
  }
  return fallback;
}
