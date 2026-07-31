import 'package:flutter/services.dart';

/// 주민등록번호에서 숫자만 (`13자리`).
String normalizeResidentRegistrationNumber(String raw) =>
    raw.replaceAll(RegExp(r'\D'), '');

/// 서버 마스킹(`******`) 등 — 그대로 저장하면 안 되는 값.
bool isMaskedResidentRegistration(String raw) => raw.contains('*');

/// PATCH/POST 본문용. 마스킹·미완성이면 `null`(필드 생략).
String? residentRegistrationForWrite(String raw) {
  if (isMaskedResidentRegistration(raw)) return null;
  final digits = normalizeResidentRegistrationNumber(raw);
  if (digits.isEmpty) return '';
  if (digits.length != 13) return null;
  return formatResidentRegistrationDisplay(digits);
}

/// `######-#######` 표시.
String formatResidentRegistrationDisplay(String raw) {
  final d = normalizeResidentRegistrationNumber(raw);
  if (d.length <= 6) return d;
  if (d.length <= 13) {
    return '${d.substring(0, 6)}-${d.substring(6)}';
  }
  final trimmed = d.substring(0, 13);
  return '${trimmed.substring(0, 6)}-${trimmed.substring(6)}';
}

/// 표시 문자열을 앞 6자리·뒤 7자리로 분리한다.
(String front, String back) splitResidentRegistrationDisplay(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return ('', '');
  final dash = trimmed.indexOf('-');
  if (dash >= 0) {
    return (trimmed.substring(0, dash), trimmed.substring(dash + 1));
  }
  final digits = normalizeResidentRegistrationNumber(trimmed);
  if (digits.length <= 6) return (digits, '');
  return (digits.substring(0, 6), digits.substring(6));
}

/// 앞·뒤 파트를 `######-#######` 형태로 합친다.
String joinResidentRegistrationParts(String front, String back) {
  final f = front.trim();
  final b = back.trim();
  if (f.isEmpty && b.isEmpty) return '';
  if (b.isEmpty) return f;
  if (f.isEmpty) return b;
  return '$f-$b';
}

/// 가입용 형식 검사. `null`이면 유효.
String? residentRegistrationFormatMessage(String raw) {
  final d = normalizeResidentRegistrationNumber(raw);
  if (d.isEmpty) return '주민등록번호를 입력해 주세요.';
  if (d.length != 13) return '주민등록번호 13자리를 입력해 주세요.';
  final month = int.tryParse(d.substring(2, 4));
  final day = int.tryParse(d.substring(4, 6));
  if (month == null ||
      day == null ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31) {
    return '주민등록번호 형식이 올바르지 않습니다.';
  }
  final genderDigit = int.tryParse(d[6]);
  if (genderDigit == null || genderDigit < 1 || genderDigit > 4) {
    return '주민등록번호 형식이 올바르지 않습니다.';
  }
  return null;
}

class ResidentRegistrationFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = normalizeResidentRegistrationNumber(newValue.text);
    final limited = digits.length > 13 ? digits.substring(0, 13) : digits;
    final formatted = formatResidentRegistrationDisplay(limited);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
