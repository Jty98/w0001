import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/util/auth_api_user_messages.dart';

/// 전역 강제 로그아웃으로 이미 안내한 인증 오류면 스낵바·토스트를 생략한다.
bool shouldSuppressHttpErrorSnackBar(Object error) {
  final h = unwrapHttpClientException(error);
  return h is HttpAuthException && h.uiMessageAlreadyShown;
}

/// 스낵바용 한 줄. 이미 전역 안내한 인증 오류면 `null`.
String? snackMessageForHttpFailure(Object error) {
  if (shouldSuppressHttpErrorSnackBar(error)) return null;
  if (error is DioException) return dioAuthRelatedUserMessage(error);
  final h = unwrapHttpClientException(error);
  if (h != null) return h.message;
  return error.toString();
}

/// Dio 오류 중 사용자에게 보여 줄 한 줄(또는 여러 줄) 요약 문구.
String dioAuthRelatedUserMessage(DioException e) {
  final err = e.error;
  if (err is HttpConnectionException) return err.message;
  if (err is HttpParseException) return err.message;

  final status = e.response?.statusCode;
  final data = e.response?.data;

  if (err is HttpAuthException) {
    if (err.uiMessageAlreadyShown) return '';
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
