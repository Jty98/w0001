import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/domain/repository/auth_abst.dart';

class AuthUseCase {
  AuthUseCase(this._repository);

  final AuthRepository _repository;

  Future<LoginResponse> login({required String uid, required String upw}) {
    return _repository.login(uid: uid, upw: upw);
  }

  Future<LoginResponse> refreshWithStoredRefresh() {
    return _repository.refreshWithStoredRefresh();
  }

  Future<UserRead> getCurrentUser() => _repository.getCurrentUser();

  Future<void> logout() => _repository.logout();

  Future<void> signup({
    required String uid,
    required String upw,
    required String uname,
  }) =>
      _repository.signup(uid: uid, upw: upw, uname: uname);
}
