import 'package:w0001/data/datasources/remote/auth/auth_api.dart';
import 'package:w0001/data/datasources/remote/auth_token_storage.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/domain/repository/auth_abst.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api);

  final AuthApi _api;

  @override
  Future<LoginResponse> login({
    required String uid,
    required String upw,
  }) async {
    final r = await _api.login(uid: uid, upw: upw);
    await AuthTokenStorage.I.write(
      access: r.accessToken,
      refresh: r.refreshToken,
    );
    return r;
  }

  @override
  Future<LoginResponse> refreshWithStoredRefresh() async {
    final rt = await AuthTokenStorage.I.readRefresh();
    if (rt == null || rt.isEmpty) {
      throw StateError('refresh_token 이 없습니다.');
    }
    final r = await _api.refresh(refreshToken: rt);
    await AuthTokenStorage.I.write(
      access: r.accessToken,
      refresh: r.refreshToken,
    );
    return r;
  }

  @override
  Future<UserRead> getCurrentUser() => _api.getMe();

  @override
  Future<void> logout() async {
    try {
      await _api.logout();
    } finally {
      await AuthTokenStorage.I.clear();
    }
  }
}
