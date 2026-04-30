import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/util/api_endpoint.dart';

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

  /// POST `/auth/signup` — 인증 헤더 없음·토큰 없음
  Future<void> signup({
    required String uid,
    required String upw,
    required String uname,
  }) async {
    await _http.post<dynamic>(
      ApiEndpoint.authSignup,
      data: signupRequestBody(uid: uid, upw: upw, uname: uname),
    );
  }

  /// GET `/auth/me` — Bearer access (인터셉터가 붙임)
  Future<UserRead> getMe() async {
    final res = await _http.get<dynamic>(ApiEndpoint.authMe);
    return UserRead.fromJson(res.data! as Map<String, dynamic>);
  }

  /// POST `/auth/logout` — Bearer access, 응답 **204** (본문 없음)
  Future<void> logout() async {
    await _http.post<dynamic>(
      ApiEndpoint.authLogout,
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
