import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kAccessToken = 'app_http_access_token';
const _kRefreshToken = 'app_http_refresh_token';

/// JWT access / refresh 를 [FlutterSecureStorage]에 보관한다.
///
/// [AppHttpClient]의 Authorization 헤더·리프레시 흐름이 동일 키를 사용한다.
final class AuthTokenStorage {
  AuthTokenStorage._();

  static final AuthTokenStorage I = AuthTokenStorage._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  Future<String?> readAccess() => _storage.read(key: _kAccessToken);

  Future<String?> readRefresh() => _storage.read(key: _kRefreshToken);

  Future<void> write({required String access, required String refresh}) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: access),
      _storage.write(key: _kRefreshToken, value: refresh),
    ]);
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
    ]);
  }
}
