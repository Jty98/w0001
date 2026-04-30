import 'package:w0001/data/model/auth_models.dart';

/// Auth(로그인·내 정보·로그아웃) 저장소 추상
abstract class AuthRepository {
  /// 로그인 후 access/refresh 를 저장한다.
  Future<LoginResponse> login({required String uid, required String upw});

  /// 저장된 refresh 로 토큰 회전 후 저장. (자동 리프레시와 별도로 수동 호출용)
  Future<LoginResponse> refreshWithStoredRefresh();

  Future<UserRead> getCurrentUser();

  /// 서버 로그아웃 시도 후 로컬 토큰은 항상 삭제한다.
  Future<void> logout();

  /// `POST /auth/signup` (role 없음, 승인 전까지 로그인 불가)
  Future<void> signup({
    required String uid,
    required String upw,
    required String uname,
  });
}
