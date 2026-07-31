import 'package:flutter/services.dart';

/// 서버 마스킹(`010-****-1234`) 등 — 그대로 저장하면 안 되는 값.
bool isMaskedPhone(String raw) => raw.contains('*');

/// 휴대폰 번호에서 숫자만 추출 (`01012345678`).
String normalizeKoreanMobilePhone(String raw) =>
    raw.replaceAll(RegExp(r'\D'), '');

/// `010-1234-5678` 형태로 표시.
String formatKoreanMobilePhoneDisplay(String raw) {
  final d = normalizeKoreanMobilePhone(raw);
  if (d.length <= 3) return d;
  if (d.length <= 7) {
    return '${d.substring(0, 3)}-${d.substring(3)}';
  }
  if (d.length <= 11) {
    return '${d.substring(0, 3)}-${d.substring(3, 7)}-${d.substring(7)}';
  }
  return '${d.substring(0, 3)}-${d.substring(3, 7)}-${d.substring(7, 11)}';
}

/// 가입·MO 인증용 형식 검사. `null`이면 유효.
String? koreanMobilePhoneFormatMessage(String raw) {
  final d = normalizeKoreanMobilePhone(raw);
  if (d.isEmpty) return '휴대폰 번호를 입력해 주세요.';
  if (!RegExp(r'^01[016789]\d{7,8}$').hasMatch(d)) {
    return '010·011·016·017·018·019로 시작하는 10~11자리 번호를 입력해 주세요.';
  }
  return null;
}

class KoreanMobilePhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = normalizeKoreanMobilePhone(newValue.text);
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    final formatted = formatKoreanMobilePhoneDisplay(limited);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
