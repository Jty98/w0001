import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';

/// `/worker-management/*` 호출 실패 시 사용자에게 보여줄 짧은 메시지.
String workerMgmtUserMessage(Object e) {
  var err = e;
  if (e is DioException && e.error != null) {
    err = e.error!;
  }
  if (err is HttpStatusException) {
    if (err.statusCode == 403) {
      return '관리자 권한이 필요합니다. '
          '승인·활동 중인 admin 계정인지 확인해 주세요.';
    }
    if (err.statusCode == 401) {
      return '로그인이 만료되었습니다. 다시 로그인해 주세요.';
    }
    return err.message;
  }
  if (err is HttpClientException) return err.message;
  return err.toString();
}
