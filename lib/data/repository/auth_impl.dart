import 'package:w0001/data/datasources/remote/auth/auth_api.dart';
import 'package:w0001/data/datasources/remote/auth_token_storage.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/phone_verification_models.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/domain/repository/auth_abst.dart';
import 'package:w0001/util/auth_forced_sign_out.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api);

  final AuthApi _api;

  @override
  Future<LoginResponse> login({
    required String uid,
    required String upw,
  }) async {
    await AuthTokenStorage.I.clear();
    resetForcedSignOutSnackThrottle();
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
    final nextRefresh = r.refreshToken.isNotEmpty ? r.refreshToken : rt;
    await AuthTokenStorage.I.write(
      access: r.accessToken,
      refresh: nextRefresh,
    );
    return LoginResponse(
      accessToken: r.accessToken,
      refreshToken: nextRefresh,
      tokenType: r.tokenType,
    );
  }

  @override
  Future<UserRead> getCurrentUser() => _api.getMe();

  @override
  Future<void> logout({bool allDevices = false}) async {
    final rt = await AuthTokenStorage.I.readRefresh();
    try {
      if (allDevices) {
        await _api.logoutAll();
      } else {
        await _api.logout(refreshToken: rt);
      }
    } finally {
      await AuthTokenStorage.I.clear();
    }
  }

  @override
  Future<bool> checkUidAvailable({required String uid}) =>
      _api.checkUidAvailable(uid: uid);

  @override
  Future<PhoneMoStartResponse> sendPhoneVerificationCode({
    required String phone,
  }) =>
      _api.sendPhoneVerificationCode(phone: phone);

  @override
  Future<PhoneMoVerifyResponse> verifyPhone({required String phone}) =>
      _api.verifyPhone(phone: phone);

  @override
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
  }) =>
      _api.signup(
        uid: uid,
        upw: upw,
        uname: uname,
        workerProfile: workerProfile,
        phone: phone,
        phoneVerificationToken: phoneVerificationToken,
        hnumber: hnumber,
        termsAgreements: termsAgreements,
        phoneForMatching: phoneForMatching,
      );
}
