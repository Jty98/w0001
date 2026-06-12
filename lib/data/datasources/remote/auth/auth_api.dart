import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/phone_verification_models.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/util/api_endpoint.dart';
import 'package:w0001/util/phone_number_format.dart';

/// Auth HTTP 엔드포인트만 담당 ([AppHttpClient] 경유).
final class AuthApi {
  AuthApi(this._http);

  final AppHttpClient _http;

  /// POST `/auth/login` — 인증 헤더 없음
  Future<LoginResponse> login({
    required String uid,
    required String upw,
  }) async {
    final res = await _http.post<dynamic>(
      ApiEndpoint.authLogin,
      data: loginRequestBody(uid, upw),
    );
    return LoginResponse.fromJson(
      res.data! as Map<String, dynamic>,
      requireRefreshTokenInResponse: true,
    );
  }

  /// POST `/auth/refresh` — 인증 헤더 없음 (토큰 회전)
  Future<LoginResponse> refresh({required String refreshToken}) async {
    final res = await _http.post<dynamic>(
      ApiEndpoint.authRefresh,
      data: refreshRequestBody(refreshToken),
    );
    return LoginResponse.fromJson(res.data! as Map<String, dynamic>);
  }

  /// GET `/auth/check-uid?uid=` — 가입 전 아이디 사용 가능 여부.
  Future<bool> checkUidAvailable({required String uid}) async {
    final res = await _http.get<dynamic>(
      ApiEndpoint.authCheckUid,
      queryParameters: <String, dynamic>{'uid': uid},
    );
    final data = res.data;
    if (data is! Map) {
      throw const FormatException('아이디 중복 확인 응답 형식이 올바르지 않습니다.');
    }
    final root = Map<String, dynamic>.from(data);
    final available = root['available'];
    if (available is bool) return available;
    throw const FormatException('아이디 중복 확인 응답 형식이 올바르지 않습니다.');
  }

  /// POST `/auth/phone/send-code` — MO 인증 시작.
  Future<PhoneMoStartResponse> sendPhoneVerificationCode({
    required String phone,
  }) async {
    final res = await _http.post<dynamic>(
      ApiEndpoint.authPhoneSendCode,
      data: <String, dynamic>{
        'phone': normalizeKoreanMobilePhone(phone),
      },
    );
    return PhoneMoStartResponse.fromJson(
      Map<String, dynamic>.from(res.data! as Map),
    );
  }

  /// POST `/auth/phone/verify` — MO 수신 확인(폴링).
  Future<PhoneMoVerifyResponse> verifyPhone({required String phone}) async {
    final res = await _http.post<dynamic>(
      ApiEndpoint.authPhoneVerify,
      data: <String, dynamic>{
        'phone': normalizeKoreanMobilePhone(phone),
      },
    );
    return PhoneMoVerifyResponse.fromJson(
      Map<String, dynamic>.from(res.data! as Map),
    );
  }

  /// POST `/auth/signup` — 인증 헤더 없음·토큰 없음
  Future<void> signup({
    required String uid,
    required String upw,
    required String uname,
    WorkerProfileRead? workerProfile,
    String? phone,
    String? phoneVerificationToken,
    String? hnumber,
    List<TermAgreementInput>? termsAgreements,
    String? phoneForMatching,
  }) async {
    await _http.post<dynamic>(
      ApiEndpoint.authSignup,
      data: signupRequestBody(
        uid: uid,
        upw: upw,
        uname: uname,
        workerProfile: workerProfile,
        phone: phone,
        phoneVerificationToken: phoneVerificationToken,
        hnumber: hnumber,
        termsAgreements: termsAgreements,
        phoneForMatching: phoneForMatching,
      ),
    );
  }

  /// GET `/auth/me` — Bearer access (인터셉터가 붙임)
  Future<UserRead> getMe() async {
    final res = await _http.get<dynamic>(ApiEndpoint.authMe);
    return UserRead.fromJson(res.data! as Map<String, dynamic>);
  }

  /// POST `/auth/logout` — Bearer access + 저장된 refresh_token, 응답 **204**
  Future<void> logout({String? refreshToken}) async {
    final rt = refreshToken?.trim() ?? '';
    await _http.post<dynamic>(
      ApiEndpoint.authLogout,
      data: rt.isNotEmpty ? refreshRequestBody(rt) : null,
      options: Options(
        responseType: ResponseType.plain,
      ),
    );
  }

  /// POST `/auth/logout-all` — 모든 기기 세션 종료, 응답 **204**
  Future<void> logoutAll() async {
    await _http.post<dynamic>(
      ApiEndpoint.authLogoutAll,
      options: Options(
        responseType: ResponseType.plain,
      ),
    );
  }

  /// POST `/auth/verify-sensitive-action` — Bearer + super_admin.
  ///
  /// 반환된 [SensitiveActionVerifyResponse.actionToken] 은 민감 사용자 API 호출 시
  /// [ApiEndpoint.headerAdminActionToken] 헤더에 넣는다.
  Future<SensitiveActionVerifyResponse> verifySensitiveAction({
    required String password,
  }) async {
    final res = await _http.post<dynamic>(
      ApiEndpoint.authVerifySensitiveAction,
      data: <String, dynamic>{'password': password},
    );
    final data = res.data;
    if (data is! Map) {
      throw const FormatException(
        '민감 작업 재인증 응답 형식이 올바르지 않습니다.',
      );
    }
    return SensitiveActionVerifyResponse.fromJson(
      Map<String, dynamic>.from(data),
    );
  }
}
