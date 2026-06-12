/// 서버 Auth 에러 공통 코드 (클라이언트 매핑용).
///
/// 서버 예: `detail: { "code": "INVALID_CREDENTIALS", "message": "...", "reason": "..." }`
abstract final class AuthApiErrorCodes {
  static const invalidCredentials = 'INVALID_CREDENTIALS';
  static const invalidOrExpiredToken = 'INVALID_OR_EXPIRED_TOKEN';
  static const invalidTokenType = 'INVALID_TOKEN_TYPE';
  static const tokenRevoked = 'TOKEN_REVOKED';
  static const userNotFound = 'USER_NOT_FOUND';
  static const refreshTokenNotFoundOrRevoked =
      'REFRESH_TOKEN_NOT_FOUND_OR_REVOKED';
  static const refreshTokenExpired = 'REFRESH_TOKEN_EXPIRED';
  static const sessionSuperseded = 'SESSION_SUPERSEDED';

  static const accountPendingApproval = 'ACCOUNT_PENDING_APPROVAL';
  static const accountRejected = 'ACCOUNT_REJECTED';
  static const accountSuspended = 'ACCOUNT_SUSPENDED';
  static const adminRequired = 'ADMIN_REQUIRED';
  static const superAdminRequired = 'SUPER_ADMIN_REQUIRED';

  static const userAlreadyExists = 'USER_ALREADY_EXISTS';
  static const validationError = 'VALIDATION_ERROR';

  static const invalidPhoneFormat = 'INVALID_PHONE_FORMAT';
  static const phoneAlreadyRegistered = 'PHONE_ALREADY_REGISTERED';
  static const octomoNotConfigured = 'OCTOMO_NOT_CONFIGURED';
  static const octomoApiError = 'OCTOMO_API_ERROR';
  static const phoneVerificationRequired = 'PHONE_VERIFICATION_REQUIRED';
  static const phoneVerificationInvalid = 'PHONE_VERIFICATION_INVALID';
  static const phoneVerificationTokenRequired =
      'PHONE_VERIFICATION_TOKEN_REQUIRED';
  static const currentPasswordInvalid = 'CURRENT_PASSWORD_INVALID';

  static const sensitiveActionPasswordMismatch =
      'SENSITIVE_ACTION_PASSWORD_MISMATCH';
  static const sensitiveActionTokenRequired = 'SENSITIVE_ACTION_TOKEN_REQUIRED';
  static const sensitiveActionTokenInvalid = 'SENSITIVE_ACTION_TOKEN_INVALID';
  static const sensitiveActionTokenMismatch = 'SENSITIVE_ACTION_TOKEN_MISMATCH';

  /// 리프레시로 복구할 수 없는 계정 상태 등(인터셉터에서 토큰 클리어 후 즉시 전달).
  static bool isInterceptorAccountBlocked(String code) {
    return code == accountRejected ||
        code == accountSuspended ||
        code == accountPendingApproval;
  }

  /// 다른 기기 로그인 등 — 리프레시 없이 토큰 삭제·로그인 화면.
  static bool isInterceptorSessionSuperseded(String code) =>
      code == sessionSuperseded;
}

/// 토큰·세션 만료류 → 동일 사용자 안내.
const String authTokenSessionUnifiedMessageKo =
    '로그인이 만료되었거나 유효하지 않습니다. 다시 로그인해 주세요.';

/// 다른 기기에서 로그인해 현재 세션이 무효화된 경우.
const String authSessionSupersededMessageKo =
    '다른 기기에서 로그인되어 로그아웃되었습니다.';

/// 서버가 JSON `detail` 객체로 줄 때 코드·메시지·사유.
class AuthStructuredDetail {
  const AuthStructuredDetail({
    required this.code,
    this.serverMessage,
    this.reason,
  });

  final String code;
  final String? serverMessage;
  final String? reason;
}

/// 응답 본문에서 `detail` 또는 `error` 객체(+ `details.reason`)를 추출한다.
///
/// 서버별로 `detail.code` / `error.code`, `reason` 또는 `details.reason` 을 허용.
AuthStructuredDetail? tryParseAuthStructuredDetail(Object? responseData) {
  if (responseData == null) return null;
  Map<String, dynamic>? root;
  if (responseData is Map<String, dynamic>) {
    root = responseData;
  } else if (responseData is Map) {
    root = Map<String, dynamic>.from(responseData);
  } else {
    return null;
  }
  final m = _extractAuthCodeMap(root);
  if (m == null) return null;
  final code = m['code']?.toString();
  if (code == null || code.isEmpty) return null;

  return AuthStructuredDetail(
    code: code,
    serverMessage: _stringOrNull(m['message']),
    reason: _reasonFromParsedMap(m),
  );
}

Map<String, dynamic>? _extractAuthCodeMap(Map<String, dynamic> root) {
  final d = root['detail'];
  if (d is Map) {
    final m = Map<String, dynamic>.from(d);
    if (m['code'] != null && m['code'].toString().trim().isNotEmpty) {
      return m;
    }
  }
  final er = root['error'];
  if (er is Map) {
    final m = Map<String, dynamic>.from(er);
    if (m['code'] != null && m['code'].toString().trim().isNotEmpty) {
      return m;
    }
  }
  return null;
}

String? _reasonFromParsedMap(Map<String, dynamic> m) {
  final top = _stringOrNull(m['reason']);
  if (top != null) return top;
  final details = m['details'];
  if (details is Map) {
    return _stringOrNull(details['reason']);
  }
  return null;
}

String? _stringOrNull(Object? v) {
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

String _appendReasonIfAny(String headline, String? reason) {
  final r = reason?.trim();
  if (r == null || r.isEmpty) return headline;
  return '$headline\n\n사유: $r';
}

/// 구조화된 `detail` 또는 HTTP 상태에 따른 사용자용 한글 안내 문구.
/// 매핑이 없으면 빈 문자열 → 호출측 기본 메시지 사용.
String localizedAuthDetailMessage({
  required int? httpStatusCode,
  required Object? responseData,
}) {
  final d = tryParseAuthStructuredDetail(responseData);
  if (d != null) {
    return _messageForStructured(d);
  }

  if (httpStatusCode == 422) {
    final summary = _fastApiValidationHint(responseData);
    if (summary != null && summary.isNotEmpty) {
      return '입력 내용을 확인해 주세요. $summary';
    }
    return '입력 내용이 올바르지 않습니다. 항목을 다시 확인해 주세요.';
  }

  return '';
}

/// [localizedAuthDetailMessage] 결과가 비어 있지 않으면 우선 사용하는 조합 문자열.
String resolveAuthRelatedUserLine({
  required int? httpStatusCode,
  required Object? responseData,
  required String fallbackMessage,
}) {
  final localized = localizedAuthDetailMessage(
    httpStatusCode: httpStatusCode,
    responseData: responseData,
  );
  if (localized.trim().isNotEmpty) return localized;
  return fallbackMessage;
}

String _messageForStructured(AuthStructuredDetail d) {
  switch (d.code) {
    case AuthApiErrorCodes.invalidCredentials:
      return '아이디 또는 비밀번호가 일치하지 않습니다.';
    case AuthApiErrorCodes.invalidOrExpiredToken:
    case AuthApiErrorCodes.invalidTokenType:
    case AuthApiErrorCodes.tokenRevoked:
    case AuthApiErrorCodes.refreshTokenNotFoundOrRevoked:
    case AuthApiErrorCodes.refreshTokenExpired:
    case AuthApiErrorCodes.sessionSuperseded:
      return authSessionSupersededMessageKo;
    case AuthApiErrorCodes.userNotFound:
      return authTokenSessionUnifiedMessageKo;
    case AuthApiErrorCodes.accountPendingApproval:
      return '관리자 승인 대기 중입니다.';
    case AuthApiErrorCodes.accountRejected:
      return _appendReasonIfAny(
        '가입 요청이 거절되었습니다.',
        d.reason,
      );
    case AuthApiErrorCodes.accountSuspended:
      return _appendReasonIfAny(
        '계정이 정지되었습니다.',
        d.reason,
      );
    case AuthApiErrorCodes.adminRequired:
    case AuthApiErrorCodes.superAdminRequired:
      return '관리자 권한이 필요합니다.';
    case AuthApiErrorCodes.userAlreadyExists:
      return '이미 사용 중인 아이디입니다.';
    case AuthApiErrorCodes.invalidPhoneFormat:
      return '휴대폰 번호 형식이 올바르지 않습니다.';
    case AuthApiErrorCodes.phoneAlreadyRegistered:
      return '이미 가입된 휴대폰 번호입니다.';
    case AuthApiErrorCodes.octomoNotConfigured:
      return '휴대폰 인증 서비스가 준비되지 않았습니다. 관리자에게 문의해 주세요.';
    case AuthApiErrorCodes.octomoApiError:
      return '휴대폰 인증 확인에 실패했습니다. 잠시 후 다시 시도해 주세요.';
    case AuthApiErrorCodes.phoneVerificationRequired:
    case AuthApiErrorCodes.phoneVerificationInvalid:
    case AuthApiErrorCodes.phoneVerificationTokenRequired:
      return '휴대폰 인증이 필요하거나 인증 정보가 만료되었습니다. 다시 인증해 주세요.';
    case AuthApiErrorCodes.currentPasswordInvalid:
      return '현재 비밀번호가 일치하지 않습니다.';
    case AuthApiErrorCodes.validationError:
      final hint = _stringOrNull(d.serverMessage);
      if (hint != null) {
        return '요청 형식 오류입니다. $hint';
      }
      return '요청 형식이 올바르지 않습니다. 입력 항목을 다시 확인해 주세요.';
    case AuthApiErrorCodes.sensitiveActionPasswordMismatch:
      return '비밀번호가 일치하지 않습니다.';
    case AuthApiErrorCodes.sensitiveActionTokenRequired:
    case AuthApiErrorCodes.sensitiveActionTokenInvalid:
      return '민감 작업 인증이 만료되었거나 없습니다. 비밀번호를 다시 입력해 주세요.';
    case AuthApiErrorCodes.sensitiveActionTokenMismatch:
      return '이 작업을 수행할 권한이 없거나 인증 정보가 맞지 않습니다.';
    default:
      final sm = _stringOrNull(d.serverMessage);
      if (sm != null) {
        return _appendReasonIfAny(sm, d.reason);
      }
      if (d.reason != null && d.reason!.trim().isNotEmpty) {
        return '오류가 발생했습니다. 사유: ${d.reason!.trim()}';
      }
      return '오류가 발생했습니다. (${d.code})';
  }
}

String? _fastApiValidationHint(Object? responseData) {
  Map<String, dynamic>? root;
  if (responseData is Map<String, dynamic>) {
    root = responseData;
  } else if (responseData is Map) {
    root = Map<String, dynamic>.from(responseData);
  } else {
    return null;
  }
  final detail = root['detail'];
  if (detail is! List || detail.isEmpty) return null;
  final parts = <String>[];
  for (final item in detail.take(4)) {
    if (item is Map && item['msg'] != null) {
      parts.add(item['msg'].toString());
    }
  }
  if (parts.isEmpty) return null;
  return parts.join(' ');
}
