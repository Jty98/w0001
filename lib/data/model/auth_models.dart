import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/util/career_input.dart';
import 'package:w0001/util/phone_number_format.dart';
import 'package:w0001/util/resident_registration_format.dart';
import 'package:w0001/util/worker_skills_parse.dart';

/// 서버 `role` 문자열과 대응 (`admin` | `worker`)
enum UserRole {
  admin('admin'),
  worker('worker');

  const UserRole(this.wireValue);

  final String wireValue;

  static UserRole parse(String raw) {
    switch (raw) {
      case 'admin':
      // 마이그레이션 호환 — 서버는 더 이상 내려주지 않음.
      case 'super_admin':
      case 'tax_admin':
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
/// * refresh 성공 시에도 서버가 새 `refresh_token`을 반드시 내려줘야 한다 (회전).
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

  /// [requireRefreshTokenInResponse]가 true일 때(로그인·갱신) 응답에 refresh가 없으면 [FormatException].
  factory LoginResponse.fromJson(
    Map<String, dynamic> json, {
    bool requireRefreshTokenInResponse = false,
  }) {
    final p = AuthTokenPayload.fromJson(json);
    if (requireRefreshTokenInResponse &&
        (p.refreshToken == null || p.refreshToken!.isEmpty)) {
      throw const FormatException(
        '인증 응답에 refresh_token 이 없거나 비었습니다.',
      );
    }
    return LoginResponse(
      accessToken: p.accessToken,
      refreshToken: p.refreshToken ?? '',
      tokenType: p.tokenType ?? 'bearer',
    );
  }
}

/// `POST /auth/signup` 응답 — JWT + 계정 상태.
class SignupResponse {
  const SignupResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.tokenType = 'bearer',
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final UserRead user;

  factory SignupResponse.fromJson(Map<String, dynamic> json) {
    final tokens = LoginResponse.fromJson(
      json,
      requireRefreshTokenInResponse: true,
    );
    return SignupResponse(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      tokenType: tokens.tokenType,
      user: UserRead.fromJson(json),
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
    this.workerHid,
    this.primarySpecialty,
    this.specialties = const [],
    this.workerRank = '',
    this.career = '',
    this.phoneMasked,
    this.phoneVerified = false,
  });

  final String uid;
  final String uname;
  final UserRole role;

  /// 서버에 필드 없으면 [UserApprovalStatus.approved] 로 간주 (레거시 호환).
  final UserApprovalStatus approvalStatus;

  /// `is_active`. 서버에 필드 없으면 true.
  final bool isActive;

  /// `/worker-management/*`·인력(hid) 연동용. 서버가 `worker_hid` 등으로 내려주면 사용.
  final int? workerHid;

  /// `GET /users`·`GET /users/{uid}` — 워커 프로필(또는 [humans] 동기화값).
  final String? primarySpecialty;

  final List<String> specialties;

  /// `GET /auth/me` — 워커 프로필과 동기화.
  final String workerRank;
  final String career;

  /// 전화번호 (마스킹된 형태)
  final String? phoneMasked;

  /// 전화번호 인증 여부
  final bool phoneVerified;

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

    int? parseWorkerHid() {
      for (final k in [
        'worker_hid',
        'workerHid',
        'human_hid',
        'humanHid',
      ]) {
        final v = json[k];
        if (v is int) return v > 0 ? v : null;
        if (v is num) {
          final i = v.toInt();
          return i > 0 ? i : null;
        }
        if (v is String) {
          final i = int.tryParse(v.trim());
          if (i != null && i > 0) return i;
        }
      }
      return null;
    }

    final approvalRaw = json['approval_status'] ??
        json['approvalStatus'] ??
        json['account_status'] ??
        json['accountStatus'];
    final activeRaw = json['is_active'] ?? json['isActive'];
    final hasApprovalKey = json.containsKey('approval_status') ||
        json.containsKey('approvalStatus') ||
        json.containsKey('account_status') ||
        json.containsKey('accountStatus');
    final hasActiveKey =
        json.containsKey('is_active') || json.containsKey('isActive');

    final approvalWire =
        approvalRaw is String ? approvalRaw : approvalRaw?.toString();

    final primarySpecialty = parseWorkerPrimarySpecialtyFromMap(json);
    final rankRaw = json['worker_rank'] ?? json['workerRank'];
    final careerRaw = json['career'];
    final phoneMaskedRaw = json['phone_masked'] ?? json['phoneMasked'];
    final phoneVerifiedRaw = json['phone_verified'] ?? json['phoneVerified'];

    return UserRead(
      uid: json['uid'] as String,
      uname: json['uname'] as String,
      role: UserRole.parse(json['role'] as String),
      approvalStatus: hasApprovalKey
          ? UserApprovalStatus.parse(approvalWire)
          : UserApprovalStatus.approved,
      isActive: hasActiveKey ? parseActive(activeRaw) : true,
      workerHid: parseWorkerHid(),
      primarySpecialty: primarySpecialty,
      specialties: const [],
      workerRank: rankRaw is String ? rankRaw.trim() : '',
      career: CareerInputUtils.parseWireField(careerRaw),
      phoneMasked: phoneMaskedRaw is String ? phoneMaskedRaw.trim() : null,
      phoneVerified: phoneVerifiedRaw == true,
    );
  }
}

/// `GET /users/me/fcm-device/status`
class FcmDeviceStatusRead {
  const FcmDeviceStatusRead({
    required this.registered,
    required this.activeDeviceCount,
  });

  final bool registered;
  final int activeDeviceCount;

  factory FcmDeviceStatusRead.fromJson(Map<String, dynamic> json) {
    bool parseBool(Object? v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.toLowerCase();
        return s == 'true' || s == '1';
      }
      return false;
    }

    int parseCount(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim()) ?? 0;
      return 0;
    }

    return FcmDeviceStatusRead(
      registered: parseBool(json['registered']),
      activeDeviceCount: parseCount(
        json['active_device_count'] ?? json['activeDeviceCount'],
      ),
    );
  }
}

Map<String, dynamic> loginRequestBody(String uid, String upw) =>
    <String, dynamic>{
      'uid': uid,
      'upw': upw,
    };

/// `POST /auth/signup` — role 없음 (서버에서 worker·pending 처리).
/// 작업자 스킬은 [workerProfile] 로 함께 전달(서버는 `primary_specialty`만 저장).
Map<String, dynamic> signupRequestBody({
  required String uid,
  required String upw,
  required String uname,
  WorkerProfileRead? workerProfile,
  String? phone,
  String? phoneVerificationToken,
  String? hnumber,
  List<TermAgreementInput>? termsAgreements,
  String? phoneForMatching,
}) {
  final body = <String, dynamic>{
    'uid': uid,
    'upw': upw,
    'uname': uname,
  };
  if (termsAgreements != null && termsAgreements.isNotEmpty) {
    body['terms_agreements'] =
        termsAgreements.map((a) => a.toJson()).toList(growable: false);
  }
  final phoneNorm = phone == null ? '' : normalizeKoreanMobilePhone(phone);
  if (phoneNorm.isNotEmpty) {
    body['phone'] = phoneNorm;
  }
  final token = phoneVerificationToken?.trim() ?? '';
  if (token.isNotEmpty) {
    body['phone_verification_token'] = token;
  }
  final hnum =
      hnumber == null ? '' : formatResidentRegistrationDisplay(hnumber).trim();
  if (hnum.isNotEmpty) {
    body['hnumber'] = hnum;
  }
  if (phoneForMatching != null && phoneForMatching.trim().isNotEmpty) {
    body['phone_for_matching'] = phoneForMatching.trim();
  }
  final profile = workerProfile;
  if (profile != null) {
    final json = profile.toJson();
    body.addAll(json);
  }
  return body;
}

/// 서버 계약: `POST /auth/refresh` 본문 필드명은 `refresh_token` 만 사용 (extra=forbid 호환).
Map<String, dynamic> refreshRequestBody(String refreshToken) =>
    <String, dynamic>{
      'refresh_token': refreshToken,
    };
