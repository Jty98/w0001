import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/phone_verification_models.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
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

  Future<void> logout({bool allDevices = false}) =>
      _repository.logout(allDevices: allDevices);

  Future<bool> checkUidAvailable({required String uid}) =>
      _repository.checkUidAvailable(uid: uid);

  Future<PhoneMoStartResponse> sendPhoneVerificationCode({
    required String phone,
  }) =>
      _repository.sendPhoneVerificationCode(phone: phone);

  Future<PhoneMoVerifyResponse> verifyPhone({required String phone}) =>
      _repository.verifyPhone(phone: phone);

  Future<SignupResponse> signup({
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
      _repository.signup(
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
