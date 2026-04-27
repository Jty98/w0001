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

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
    );
  }
}

/// GET `/auth/me` 응답
class UserRead {
  const UserRead({
    required this.uid,
    required this.uname,
    required this.role,
  });

  final String uid;
  final String uname;
  final UserRole role;

  factory UserRead.fromJson(Map<String, dynamic> json) {
    return UserRead(
      uid: json['uid'] as String,
      uname: json['uname'] as String,
      role: UserRole.parse(json['role'] as String),
    );
  }
}

Map<String, dynamic> loginRequestBody(String uid, String upw) => <String, dynamic>{
      'uid': uid,
      'upw': upw,
    };

Map<String, dynamic> refreshRequestBody(String refreshToken) => <String, dynamic>{
      'refresh_token': refreshToken,
    };
