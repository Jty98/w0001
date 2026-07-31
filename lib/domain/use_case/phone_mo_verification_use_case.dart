import 'package:w0001/data/model/phone_verification_models.dart';
import 'package:w0001/domain/repository/auth_abst.dart';
import 'package:w0001/util/phone_mo/phone_mo_sms_launcher.dart';
import 'package:w0001/util/phone_number_format.dart';

class PhoneMoVerificationUseCase {
  PhoneMoVerificationUseCase(this._auth);

  final AuthRepository _auth;

  Future<PhoneMoStartResponse> start(String phone) =>
      _auth.sendPhoneVerificationCode(phone: phone);

  Future<PhoneMoVerifyResponse> verify(String phone) =>
      _auth.verifyPhone(phone: phone);

  /// 문자 앱(iOS는 앱 내 composer)을 열어 MO 인증 문자를 보낸다.
  Future<PhoneMoSmsComposeResult> composeMoSms({
    required String moNumber,
    required String body,
  }) =>
      PhoneMoSmsLauncher.compose(moNumber: moNumber, body: body);

  /// @deprecated [composeMoSms] 사용
  Future<bool> openSmsComposer({
    required String moNumber,
    required String body,
  }) async {
    final result = await composeMoSms(moNumber: moNumber, body: body);
    return result == PhoneMoSmsComposeResult.sent ||
        result == PhoneMoSmsComposeResult.external;
  }

  /// MO 인증 1회 확인.
  Future<String?> tryVerifyOnce(String phone) async {
    final normalized = normalizeKoreanMobilePhone(phone);
    final result = await _auth.verifyPhone(phone: normalized);
    if (result.status == 'verified' &&
        result.phoneVerificationToken != null &&
        result.phoneVerificationToken!.isNotEmpty) {
      return result.phoneVerificationToken;
    }
    if (result.status == 'expired') {
      throw Exception(
        result.message.isNotEmpty
            ? result.message
            : '인증 세션이 만료되었습니다. 인증코드를 다시 발급받아 주세요.',
      );
    }
    return null;
  }

  /// MO 인증 완료까지 폴링. [shouldContinue]가 false면 중단.
  Future<String> waitUntilVerified(
    String phone, {
    Duration timeout = const Duration(minutes: 5),
    Duration interval = const Duration(seconds: 3),
    bool Function()? shouldContinue,
  }) async {
    final normalized = normalizeKoreanMobilePhone(phone);
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (shouldContinue != null && !shouldContinue()) {
        throw StateError('인증 확인이 취소되었습니다.');
      }
      final token = await tryVerifyOnce(normalized);
      if (token != null) return token;
      await Future<void>.delayed(interval);
    }
    throw Exception('인증 시간이 초과되었습니다. 다시 시도해 주세요.');
  }
}
