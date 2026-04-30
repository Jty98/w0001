/// 서버 `role` 문자열과 대응 (`super_admin` | `admin` | `worker`)
enum UserRole {
  superAdmin('super_admin'),
  admin('admin'),
  worker('worker');

  const UserRole(this.wireValue);

  final String wireValue;

  static UserRole parse(String raw) {
    switch (raw) {
      case 'super_admin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'worker':
        return UserRole.worker;
      default:
        throw FormatException('알 수 없는 role: $raw');
    }
  }

  /// UI 표시용 (한국어)
  String get labelKo {
    switch (this) {
      case UserRole.superAdmin:
        return '슈퍼관리자';
      case UserRole.admin:
        return '관리자';
      case UserRole.worker:
        return '작업자';
    }
  }
}

/// 로그인·`POST /auth/refresh` 응답 본문에서 토큰 추출.
///
/// * snake_case / camelCase / 최상위 `data` 래핑 모두 처리
/// * 갱신 응답에서 `refresh`를 생략하면 [refreshToken]은 null (회전 없이 access만 교체)
class AuthTokenPayload {
  const AuthTokenPayload({
    required this.accessToken,
    this.refreshToken,
    this.tokenType,
  });

  final String accessToken;
  final String? refreshToken;
  final String? tokenType;

  factory AuthTokenPayload.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> root = json;
    final wrapped = json['data'];
    if (wrapped is Map<String, dynamic>) {
      root = Map<String, dynamic>.from(wrapped);
    }

    String? pickString(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    final access = pickString(root, ['access_token', 'accessToken']) ??
        pickString(json, ['access_token', 'accessToken']);
    if (access == null) {
      throw FormatException(
        'access 토큰 필드가 없습니다. keys=${json.keys.toList()}',
      );
    }
    final refresh = pickString(root, ['refresh_token', 'refreshToken']) ??
        pickString(json, ['refresh_token', 'refreshToken']);
    final tt = pickString(root, ['token_type', 'tokenType']) ??
        pickString(json, ['token_type', 'tokenType']);

    return AuthTokenPayload(
      accessToken: access,
      refreshToken: refresh,
      tokenType: tt,
    );
  }
}

/// POST `/auth/login`, `/auth/refresh` 응답
class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
  });

  final String accessToken;
  final String refreshToken;
  /// 기본 `"bearer"`
  final String tokenType;

  /// [requireRefreshTokenInResponse]가 true일 때(로그인) 응답에 refresh가 없으면 [FormatException].
  /// 갱신 API는 access만 내려줄 수 있어 false가 기본값.
  factory LoginResponse.fromJson(
    Map<String, dynamic> json, {
    bool requireRefreshTokenInResponse = false,
  }) {
    final p = AuthTokenPayload.fromJson(json);
    if (requireRefreshTokenInResponse &&
        (p.refreshToken == null || p.refreshToken!.isEmpty)) {
      throw const FormatException(
        '로그인 응답에 refresh_token 이 없거나 비었습니다.',
      );
    }
    return LoginResponse(
      accessToken: p.accessToken,
      refreshToken: p.refreshToken ?? '',
      tokenType: p.tokenType ?? 'bearer',
    );
  }
}

/// POST `/auth/verify-sensitive-action` 성공 시 [actionToken] 을 대상 사용자 API 헤더에 실어 보낸다.
class SensitiveActionVerifyResponse {
  const SensitiveActionVerifyResponse({
    required this.actionToken,
    this.tokenType,
    this.expiresInSeconds,
  });

  factory SensitiveActionVerifyResponse.fromJson(Map<String, dynamic> json) {
    String? pickString(Iterable<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    int? pickInt(Iterable<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is int) return v;
        if (v is num) return v.toInt();
      }
      return null;
    }

    final token = pickString(['action_token', 'actionToken']);
    if (token == null) {
      throw FormatException(
        'action_token 필드가 없습니다. keys=${json.keys.toList()}',
      );
    }
    return SensitiveActionVerifyResponse(
      actionToken: token,
      tokenType: pickString(['token_type', 'tokenType']),
      expiresInSeconds: pickInt(['expires_in_seconds', 'expiresInSeconds']),
    );
  }

  final String actionToken;
  final String? tokenType;
  final int? expiresInSeconds;
}

/// 서버 `approval_status`: pending → 승인 전, rejected → 거절, approved → 이용 가능.
enum UserApprovalStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const UserApprovalStatus(this.wireValue);
  final String wireValue;

  static UserApprovalStatus parse(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'pending':
        return UserApprovalStatus.pending;
      case 'rejected':
        return UserApprovalStatus.rejected;
      case 'approved':
        return UserApprovalStatus.approved;
      default:
        return UserApprovalStatus.approved;
    }
  }

  String get labelKo => switch (this) {
        UserApprovalStatus.pending => '승인 대기',
        UserApprovalStatus.approved => '승인됨',
        UserApprovalStatus.rejected => '거절됨',
      };
}

/// GET `/auth/me` 응답 (+ 슈퍼관리자 사용자 목록)
class UserRead {
  const UserRead({
    required this.uid,
    required this.uname,
    required this.role,
    this.approvalStatus = UserApprovalStatus.approved,
    this.isActive = true,
  });

  final String uid;
  final String uname;
  final UserRole role;
  /// 서버에 필드 없으면 [UserApprovalStatus.approved] 로 간주 (레거시 호환).
  final UserApprovalStatus approvalStatus;
  /// `is_active`. 서버에 필드 없으면 true.
  final bool isActive;

  factory UserRead.fromJson(Map<String, dynamic> json) {
    bool parseActive(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.toLowerCase();
        return s == 'true' || s == '1' || s == 'yes';
      }
      return true;
    }

    final approvalRaw = json['approval_status'] ?? json['approvalStatus'];
    final activeRaw = json['is_active'] ?? json['isActive'];
    final hasApprovalKey =
        json.containsKey('approval_status') ||
            json.containsKey('approvalStatus');
    final hasActiveKey =
        json.containsKey('is_active') || json.containsKey('isActive');

    final approvalWire =
        approvalRaw is String ? approvalRaw : approvalRaw?.toString();

    return UserRead(
      uid: json['uid'] as String,
      uname: json['uname'] as String,
      role: UserRole.parse(json['role'] as String),
      approvalStatus: hasApprovalKey
          ? UserApprovalStatus.parse(approvalWire)
          : UserApprovalStatus.approved,
      isActive:
          hasActiveKey ? parseActive(activeRaw) : true,
    );
  }
}

Map<String, dynamic> loginRequestBody(String uid, String upw) => <String, dynamic>{
      'uid': uid,
      'upw': upw,
    };

/// `POST /auth/signup` — role 없음 (서버에서 worker·pending 처리).
Map<String, dynamic> signupRequestBody({
  required String uid,
  required String upw,
  required String uname,
}) =>
    <String, dynamic>{
      'uid': uid,
      'upw': upw,
      'uname': uname,
    };

/// 서버 계약: `POST /auth/refresh` 본문 필드명은 `refresh_token` 만 사용 (extra=forbid 호환).
Map<String, dynamic> refreshRequestBody(String refreshToken) => <String, dynamic>{
      'refresh_token': refreshToken,
    };
