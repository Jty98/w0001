import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/util/auth_api_user_messages.dart';

/// 서버 예: `{ "error": { "code": "WORKER_ROLE_REQUIRED", ... } }`
abstract final class WorkerApiErrorCodes {
  static const workerRoleRequired = 'WORKER_ROLE_REQUIRED';
}

String? workerDashboardFriendlyMessageKo(HttpClientException error) {
  if (error is! HttpStatusException) return null;
  final detail = tryParseAuthStructuredDetail(error.body);
  if (detail?.code == WorkerApiErrorCodes.workerRoleRequired) {
    return '작업자 전용 메뉴입니다.';
  }
  if (error.statusCode == 403) {
    return '이 현장 정보를 볼 권한이 없습니다.';
  }
  if (error.statusCode == 404) {
    return '현장을 찾을 수 없습니다.';
  }
  return null;
}
