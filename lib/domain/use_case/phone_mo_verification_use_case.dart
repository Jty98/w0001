import 'package:url_launcher/url_launcher.dart';
import 'package:w0001/data/model/phone_verification_models.dart';
import 'package:w0001/domain/repository/auth_abst.dart';
import 'package:w0001/util/phone_number_format.dart';

class PhoneMoVerificationUseCase {
  PhoneMoVerificationUseCase(this._auth);

  final AuthRepository _auth;

  Future<PhoneMoStartResponse> start(String phone) =>
      _auth.sendPhoneVerificationCode(phone: phone);

  Future<PhoneMoVerifyResponse> verify(String phone) =>
      _auth.verifyPhone(phone: phone);

  /// 문자 앱을 열어 수신번호·본문을 미리 채움.
  Future<bool> openSmsComposer({
    required String moNumber,
    required String body,
  }) async {
    final digits = moNumber.replaceAll(RegExp(r'\D'), '');
    final uri = Uri(
      scheme: 'sms',
      path: digits,
      queryParameters: body.isEmpty ? null : <String, String>{'body': body},
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
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
      final result = await _auth.verifyPhone(phone: normalized);
      if (result.status == 'verified' &&
          result.phoneVerificationToken != null &&
          result.phoneVerificationToken!.isNotEmpty) {
        return result.phoneVerificationToken!;
      }
      if (result.status == 'expired') {
        throw Exception(
          result.message.isNotEmpty
              ? result.message
              : '인증 세션이 만료되었습니다. 인증코드를 다시 발급받아 주세요.',
        );
      }
      await Future<void>.delayed(interval);
    }
    throw Exception('인증 시간이 초과되었습니다. 다시 시도해 주세요.');
  }
}
