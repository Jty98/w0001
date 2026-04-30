import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/util/auth_api_user_messages.dart';

/// Dio 오류 중 사용자에게 보여 줄 한 줄(또는 여러 줄) 요약 문구.
String dioAuthRelatedUserMessage(DioException e) {
  final err = e.error;
  if (err is HttpConnectionException) return err.message;
  if (err is HttpParseException) return err.message;

  final status = e.response?.statusCode;
  final data = e.response?.data;

  if (err is HttpAuthException) {
    final fromBody = localizedAuthDetailMessage(
      httpStatusCode: status,
      responseData: data,
    );
    if (fromBody.trim().isNotEmpty) return fromBody;
    return err.message;
  }

  if (err is HttpStatusException) {
    final fromBody = localizedAuthDetailMessage(
      httpStatusCode: status,
      responseData: data,
    );
    if (fromBody.trim().isNotEmpty) return fromBody;
    return err.message;
  }

  final onlyBody = localizedAuthDetailMessage(
    httpStatusCode: status,
    responseData: data,
  );
  if (onlyBody.trim().isNotEmpty) return onlyBody;

  return e.message ?? '요청에 실패했습니다.';
}
