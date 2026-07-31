import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/phone_verification_models.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/data/model/worker_profile_model.dart';

/// Auth(로그인·내 정보·로그아웃) 저장소 추상
abstract class AuthRepository {
  /// 로그인 후 access/refresh 를 저장한다.
  Future<LoginResponse> login({required String uid, required String upw});

  /// 저장된 refresh 로 토큰 회전 후 저장. (자동 리프레시와 별도로 수동 호출용)
  Future<LoginResponse> refreshWithStoredRefresh();

  Future<UserRead> getCurrentUser();

  /// 서버 로그아웃 시도 후 로컬 토큰은 항상 삭제한다.
  ///
  /// [allDevices]가 true이면 `POST /auth/logout-all`, 아니면 refresh_token 포함
  /// `POST /auth/logout`.
  Future<void> logout({bool allDevices = false});

  /// `GET /auth/check-uid` — `true`면 가입 가능.
  Future<bool> checkUidAvailable({required String uid});

  Future<PhoneMoStartResponse> sendPhoneVerificationCode({
    required String phone,
  });

  Future<PhoneMoVerifyResponse> verifyPhone({required String phone});

  /// `POST /auth/signup` — JWT 발급 + 승인 대기 세션 시작.
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
  });
}
