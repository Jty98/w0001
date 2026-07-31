import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:w0001/data/datasources/remote/auth_token_storage.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/util/api_endpoint.dart';
import 'package:w0001/util/auth_api_user_messages.dart';
import 'package:w0001/util/auth_debug_log.dart';
import 'package:w0001/util/auth_forced_sign_out.dart';

// ---------------------------------------------------------------------------
// Exceptions (CRUD / 네트워크 공통)
// ---------------------------------------------------------------------------

/// [AppHttpClient]에서 쓰는 API 예외의 공통 기반.
sealed class HttpClientException implements Exception {
  const HttpClientException(this.message, {this.cause, this.statusCode});

  final String message;
  final Object? cause;
  final int? statusCode;

  @override
  String toString() => 'HttpClientException: $message';
}

/// 연결/타임아웃/소켓 오류
final class HttpConnectionException extends HttpClientException {
  const HttpConnectionException(String message, {Object? super.cause})
      : super(message);
}

/// HTTP 4xx/5xx(응답 본문 포함)
final class HttpStatusException extends HttpClientException {
  const HttpStatusException(
    String message, {
    super.cause,
    super.statusCode,
    this.body,
  }) : super(message);

  final Object? body;
}

/// 인증/리프레시 실패
final class HttpAuthException extends HttpClientException {
  const HttpAuthException(
    String message, {
    Object? super.cause,
    super.statusCode,
    this.uiMessageAlreadyShown = false,
  }) : super(message);

  /// [performAuthForcedSignOut] 등에서 이미 안내한 경우 화면별 스낵바 생략.
  final bool uiMessageAlreadyShown;
}

/// JSON 등 파싱 실패
final class HttpParseException extends HttpClientException {
  const HttpParseException(String message, {Object? super.cause})
      : super(message);
}

// ---------------------------------------------------------------------------
// App HTTP (Dio) — GET/POST/PATCH/DELETE, JWT, refresh
// ([AuthTokenStorage]에 토큰 보관)
// ---------------------------------------------------------------------------

/// `dotenv`에 `base_url` 필수. [init]은 [main]에서 [dotenv.load] 이후 호출.
///
/// * `Authorization: Bearer {access_token}` (로그인·회원가입·리프레시 경로는 제외)
/// * 401 → [리프레시] 후 원 요청 1회 재시도(리프레시 본인 / 이미 재시도한 경우 제외)
final class AppHttpClient {
  AppHttpClient._();

  static final AppHttpClient I = AppHttpClient._();

  static const _retryExtraKey = 'app_http_did_refresh_retry';

  late final Dio _dio;
  late String _baseUrl;
  late String _refreshPath;
  late String _loginPath;
  late String _signupPath;

  Future<void>? _ongoingRefresh;
  bool _isInit = false;

  /// 네트워크 오류 스낵바 중복 표시 방지용
  static DateTime? _lastNetworkErrorSnackbarTime;
  static const _networkErrorSnackbarThrottleDuration = Duration(seconds: 3);

  /// 네트워크 오류 스낵바를 표시하기 위한 NavigatorKey (main.dart에서 설정)
  static GlobalKey<NavigatorState>? rootNavigatorKey;

  bool get isInitialized => _isInit;

  Dio get raw => _dio;

  /// 선택 `.env` 키: `auth_refresh_path`, `auth_login_path`, `auth_signup_path`
  Future<void> init(
      {Duration? connectTimeout, Duration? receiveTimeout}) async {
    final base = dotenv.env['base_url']?.trim();
    if (base == null || base.isEmpty) {
      throw StateError(
          'dotenv에 base_url이 없습니다. (예: base_url=https://api.example.com)');
    }
    _baseUrl = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    _refreshPath =
        (dotenv.env['auth_refresh_path']?.trim() ?? ApiEndpoint.authRefresh);
    if (!_refreshPath.startsWith('/')) {
      _refreshPath = '/$_refreshPath';
    }
    _loginPath =
        (dotenv.env['auth_login_path']?.trim() ?? ApiEndpoint.authLogin);
    if (!_loginPath.startsWith('/')) {
      _loginPath = '/$_loginPath';
    }
    _signupPath =
        (dotenv.env['auth_signup_path']?.trim() ?? ApiEndpoint.authSignup);
    if (!_signupPath.startsWith('/')) {
      _signupPath = '/$_signupPath';
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: connectTimeout ?? const Duration(seconds: 20),
        receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        // 2xx만 성공 → 그 외는 onError(401에서 리프레시)
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_shouldSkipAuthHeader(options)) {
            return handler.next(options);
          }
          final t = await AuthTokenStorage.I.readAccess();
          if (t != null && t.isNotEmpty) {
            options.headers[HttpHeaders.authorizationHeader] = 'Bearer $t';
          }
          return handler.next(options);
        },
        onError: (err, handler) {
          if (err.response?.statusCode == 401) {
            return _onUnauthorized401(err, handler);
          }
          return handler.next(_mapDioToClientException(err));
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (o) => debugPrint(o.toString()),
        ),
      );
    }
    _isInit = true;
  }

  /// [baseUrl]에 `/api/v1` 등 prefix가 있으면 [RequestOptions.uri.path]는 `/api/v1/auth/login` 형태가 된다.
  /// 이 경우에도 로그인·리프레시에는 Bearer를 붙이지 않는다(만료 access로 401·혼선 방지).
  bool _pathMatchesAuthRoute(String requestPath, String configuredPath) {
    return requestPath == configuredPath ||
        requestPath.endsWith(configuredPath);
  }

  bool _isPublicTermsPath(String p) {
    return p == ApiEndpoint.terms || p.startsWith('${ApiEndpoint.terms}/');
  }

  bool _shouldSkipAuthHeader(RequestOptions o) {
    final p = o.uri.path;
    if (_pathMatchesAuthRoute(p, _loginPath)) return true;
    if (_pathMatchesAuthRoute(p, _refreshPath)) return true;
    if (_pathMatchesAuthRoute(p, _signupPath)) return true;
    if (_pathMatchesAuthRoute(p, ApiEndpoint.authCheckUid)) return true;
    if (_pathMatchesAuthRoute(p, ApiEndpoint.authPhoneSendCode)) return true;
    if (_pathMatchesAuthRoute(p, ApiEndpoint.authPhoneVerify)) return true;
    if (_isPublicTermsPath(p)) return true;
    return false;
  }

  bool _isRefreshRequest(RequestOptions o) =>
      _pathMatchesAuthRoute(o.uri.path, _refreshPath);

  /// 로그인·회원가입·아이디 중복 확인 등 공개 Auth — Bearer·401 리프레시 없음.
  bool _isPublicAuthRequest(RequestOptions o) {
    final p = o.uri.path;
    return _pathMatchesAuthRoute(p, _loginPath) ||
        _pathMatchesAuthRoute(p, _signupPath) ||
        _pathMatchesAuthRoute(p, ApiEndpoint.authCheckUid) ||
        _pathMatchesAuthRoute(p, ApiEndpoint.authPhoneSendCode) ||
        _pathMatchesAuthRoute(p, ApiEndpoint.authPhoneVerify) ||
        _isPublicTermsPath(p);
  }

  void _onUnauthorized401(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    final req = err.requestOptions;
    if (req.extra[_retryExtraKey] == true) {
      return handler.next(_mapDioToClientException(err));
    }
    if (_isRefreshRequest(req)) {
      // 리프레시 API가 401이면 루프 방지: 그대로 매핑
      return handler.next(_mapDioToClientException(err));
    }
    if (_isPublicAuthRequest(req)) {
      return handler.next(_mapDioToClientException(err));
    }

    final structured = tryParseAuthStructuredDetail(err.response?.data);
    if (structured != null &&
        AuthApiErrorCodes.isInterceptorForceReauth(structured)) {
      unawaited(_handleForceReauth401(err, handler, structured));
      return;
    }
    if (structured != null &&
        AuthApiErrorCodes.isInterceptorAccountBlocked(structured.code)) {
      unawaited(_clearAuthThenNext401(err, handler));
      return;
    }

    unawaited(_refreshAndRetry(err, handler));
  }

  Future<void> _handleForceReauth401(
    DioException err,
    ErrorInterceptorHandler handler,
    AuthStructuredDetail structured,
  ) async {
    authDebugLog('access 401, code=${structured.code} → force reauth');
    final msg = resolveForceReauthUserMessage(responseData: err.response?.data);
    await performAuthForcedSignOut(msg);
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        type: DioExceptionType.badResponse,
        error: HttpAuthException(
          msg,
          statusCode: 401,
          uiMessageAlreadyShown: true,
        ),
        response: err.response,
      ),
    );
  }

  Future<void> _clearAuthThenNext401(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final msg = localizedAuthDetailMessage(
      httpStatusCode: err.response?.statusCode,
      responseData: err.response?.data,
    );
    await performAuthForcedSignOut(
      msg.trim().isNotEmpty ? msg : '계정 이용이 제한되었습니다.',
    );
    handler.next(_mapDioToClientException(err));
  }

  Future<void> _refreshAndRetry(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final failed = err.requestOptions;
    final refreshToken = await AuthTokenStorage.I.readRefresh();
    if (refreshToken == null || refreshToken.isEmpty) {
      authDebugLog('refresh skipped: no stored refresh_token');
      final msg =
          resolveForceReauthUserMessage(responseData: err.response?.data);
      await performAuthForcedSignOut(msg);
      return handler.next(
        DioException(
          requestOptions: failed,
          type: DioExceptionType.badResponse,
          error: HttpAuthException(
            msg,
            statusCode: 401,
            uiMessageAlreadyShown: true,
          ),
          response: err.response,
        ),
      );
    }
    try {
      await _runRefreshOrWait(refreshToken);
    } on HttpClientException catch (e) {
      return handler.next(
        DioException(
          requestOptions: failed,
          type: DioExceptionType.unknown,
          error: e,
        ),
      );
    } catch (e) {
      return handler.next(
        DioException(
          requestOptions: failed,
          type: DioExceptionType.unknown,
          error: HttpConnectionException('토큰 갱신 실패', cause: e),
        ),
      );
    }
    final newReq = failed.copyWith(
      extra: Map<String, dynamic>.from(failed.extra)..[_retryExtraKey] = true,
    );
    try {
      final res = await _dio.fetch<dynamic>(newReq);
      return handler.resolve(res);
    } on DioException catch (e) {
      if (e.error is HttpClientException) {
        return handler.next(e);
      }
      return handler.next(_mapDioToClientException(e));
    } catch (e) {
      return handler.next(
        DioException(
          requestOptions: failed,
          type: DioExceptionType.unknown,
          error: HttpConnectionException('요청 재시도 실패', cause: e),
        ),
      );
    }
  }

  /// POST [path] body [refreshRequestBody] (`refresh_token` 단일)·응답은 [AuthTokenPayload]
  Future<void> _runRefreshOrWait(String refreshToken) {
    if (_ongoingRefresh != null) {
      return _ongoingRefresh!;
    }
    _ongoingRefresh = _refreshTokensOnce(refreshToken);
    return _ongoingRefresh!.whenComplete(() {
      _ongoingRefresh = null;
    });
  }

  Future<void> _refreshTokensOnce(String refreshToken) async {
    authDebugLogRefreshStart();
    final plain = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: _dio.options.connectTimeout,
        receiveTimeout: _dio.options.receiveTimeout,
        contentType: Headers.jsonContentType,
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );
    final Response<dynamic> res;
    try {
      res = await plain.post<dynamic>(
        _refreshPath,
        data: refreshRequestBody(refreshToken),
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401) {
        authDebugLogRefreshFail(responseData: e.response?.data);
        throw await _refreshFailureSignOut(
          responseData: e.response?.data,
          cause: e,
        );
      }
      // 타임아웃·연결 끊김 등 일시 오류에서는 저장된 토큰을 유지한다 (재시도·오프라인 복귀 대비).
      final transient = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError;
      if (transient || code == null) {
        throw HttpConnectionException(
          '네트워크 오류로 토큰을 갱신하지 못했습니다.',
          cause: e,
        );
      }
      throw HttpStatusException(
        '토큰 갱신에 실패했습니다.',
        statusCode: code,
        body: e.response?.data,
        cause: e,
      );
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      authDebugLogRefreshFail(responseData: res.data);
      throw await _refreshFailureSignOut(
        responseData: res.data,
        cause: res,
      );
    }
    final data = res.data;
    if (data is! Map) {
      authDebugLogRefreshFail(responseData: data);
      throw await _refreshFailureSignOut(
        responseData: data,
        cause: const FormatException('토큰 응답 형식이 올바르지 않습니다.'),
      );
    }
    AuthTokenPayload p;
    try {
      p = AuthTokenPayload.fromJson(Map<String, dynamic>.from(data));
    } on FormatException catch (e) {
      authDebugLogRefreshFail(responseData: data);
      throw await _refreshFailureSignOut(
        responseData: data,
        cause: e,
      );
    }
    if (p.refreshToken == null || p.refreshToken!.isEmpty) {
      authDebugLog('refresh ok but refresh_token missing in response');
      throw await _refreshFailureSignOut(
        responseData: data,
        cause: const FormatException('갱신 응답에 refresh_token 이 없습니다.'),
      );
    }
    await AuthTokenStorage.I.write(
      access: p.accessToken,
      refresh: p.refreshToken!,
    );
    authDebugLogRefreshOk(
      access: p.accessToken,
      refresh: p.refreshToken!,
    );
  }

  /// refresh 실패·응답 불완전 시 토큰 삭제 후 로그인 화면으로 보낸다.
  Future<HttpAuthException> _refreshFailureSignOut({
    required Object? responseData,
    required Object cause,
  }) async {
    await AuthTokenStorage.I.clear();
    final msg = resolveForceReauthUserMessage(responseData: responseData);
    await performAuthForcedSignOut(msg);
    return HttpAuthException(
      msg,
      statusCode: 401,
      cause: cause,
      uiMessageAlreadyShown: true,
    );
  }

  // --- CRUD ---

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Object? data,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _request<T>(
      'GET',
      path,
      queryParameters: queryParameters,
      data: data,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _request<T>(
      'POST',
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _request<T>(
      'PATCH',
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _request<T>(
      'PUT',
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _request<T>(
      'DELETE',
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> _request<T>(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    if (!_isInit) {
      throw StateError('AppHttpClient.init() 를 먼저 호출하세요.');
    }
    return _dio.request<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: (options ?? Options()).copyWith(method: method),
      cancelToken: cancelToken,
    );
  }

  /// 로그인 API 성공 후: [AuthTokenStorage]에 저장(또는 직접 [AuthTokenStorage.I.write] 호출).
  Future<void> setTokens({required String access, required String refresh}) {
    authDebugLogTokensSaved(
      event: 'setTokens',
      access: access,
      refresh: refresh,
    );
    return AuthTokenStorage.I.write(access: access, refresh: refresh);
  }

  Future<void> clearAuth() => AuthTokenStorage.I.clear();

  DioException _mapDioToClientException(DioException e) {
    if (e.error is HttpClientException) {
      return e;
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        _showNetworkErrorSnackbar('요청 시간이 초과되었습니다.');
        return DioException(
          requestOptions: e.requestOptions,
          type: e.type,
          error: HttpConnectionException('요청 시간이 초과되었습니다.', cause: e),
        );
      case DioExceptionType.connectionError:
        _showNetworkErrorSnackbar('네트워크 연결을 확인해주세요.');
        return DioException(
          requestOptions: e.requestOptions,
          type: e.type,
          error: HttpConnectionException('네트워크에 연결할 수 없습니다.', cause: e),
        );
      case DioExceptionType.badResponse:
        final c = e.response?.statusCode;
        final b = e.response?.data;
        if (c == 401) {
          // `detail.code` 없을 때: 로그인 호출면 자격증명 실패, 그 외는 토큰/세션 문제로 안내.
          final p401 = e.requestOptions.uri.path;
          final fallback401 = _pathMatchesAuthRoute(p401, _loginPath)
              ? '아이디 또는 비밀번호가 일치하지 않습니다.'
              : authTokenSessionUnifiedMessageKo;
          final msg = resolveAuthRelatedUserLine(
            httpStatusCode: 401,
            responseData: b,
            fallbackMessage: fallback401,
          );
          return DioException(
            requestOptions: e.requestOptions,
            type: e.type,
            error: HttpAuthException(msg, statusCode: 401),
            response: e.response,
          );
        }
        final statusMsg = resolveAuthRelatedUserLine(
          httpStatusCode: c,
          responseData: b,
          fallbackMessage: '서버 응답 오류 (HTTP $c)',
        );
        return DioException(
          requestOptions: e.requestOptions,
          type: e.type,
          error: HttpStatusException(
            statusMsg,
            statusCode: c,
            body: b,
            cause: e,
          ),
          response: e.response,
        );
      default:
        _showNetworkErrorSnackbar('네트워크 연결을 확인해주세요.');
        return DioException(
          requestOptions: e.requestOptions,
          type: e.type,
          error: HttpConnectionException('요청에 실패했습니다.', cause: e),
        );
    }
  }

  /// 네트워크 오류 스낵바를 표시합니다. (중복 표시 방지 로직 포함)
  void _showNetworkErrorSnackbar(String message) {
    final now = DateTime.now();
    if (_lastNetworkErrorSnackbarTime != null &&
        now.difference(_lastNetworkErrorSnackbarTime!) <
            _networkErrorSnackbarThrottleDuration) {
      return;
    }
    _lastNetworkErrorSnackbarTime = now;

    final navKey = rootNavigatorKey;
    if (navKey == null || navKey.currentContext == null) return;

    final messenger = ScaffoldMessenger.maybeOf(navKey.currentContext!);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}

extension AppHttpClientDioX on DioException {
  HttpClientException? get httpClientError =>
      error is HttpClientException ? error as HttpClientException : null;
}

/// [DioException.error]에 감싸진 [HttpClientException] 또는 그대로인 예외를 꺼낸다.
HttpClientException? unwrapHttpClientException(Object error) {
  if (error is HttpClientException) return error;
  if (error is DioException) return error.httpClientError;
  return null;
}

/// `place-work-days` 등에서 트러블 페어로 인한 409 응답인지.
///
/// 서버: `error.code == WORKER_CONFLICT_PAIR_WARNING`, `acknowledge_required: true` 등.
/// 구형 응답은 본문 메시지 힌트로 판별.
bool isWorkerTroublePairConflictError(Object error) {
  final h = unwrapHttpClientException(error);
  if (h == null || h.statusCode != 409) return false;
  if (h is HttpStatusException) {
    final body = h.body;
    if (_isWorkerConflictPairWarningBody(body)) return true;
  }
  final m = h.message.toLowerCase();
  return m.contains('worker pair') ||
      m.contains('cannot be assigned together') ||
      m.contains('conflict warning');
}

bool _isWorkerConflictPairWarningBody(Object? body) {
  Map<String, dynamic>? errMap;
  if (body is Map) {
    final m = Map<String, dynamic>.from(body);
    final e = m['error'];
    if (e is Map) {
      errMap = Map<String, dynamic>.from(e);
    } else {
      final d = m['detail'];
      if (d is Map) errMap = Map<String, dynamic>.from(d);
    }
  }
  if (errMap == null) return false;
  if (errMap['code']?.toString() == 'WORKER_CONFLICT_PAIR_WARNING') {
    return true;
  }
  if (errMap['acknowledge_required'] == true) return true;
  return false;
}
