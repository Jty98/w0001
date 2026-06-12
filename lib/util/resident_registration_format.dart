import 'package:flutter/services.dart';

/// 주민등록번호에서 숫자만 (`13자리`).
String normalizeResidentRegistrationNumber(String raw) =>
    raw.replaceAll(RegExp(r'\D'), '');

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

/// 가입용 형식 검사. `null`이면 유효.
String? residentRegistrationFormatMessage(String raw) {
  final d = normalizeResidentRegistrationNumber(raw);
  if (d.isEmpty) return '주민등록번호를 입력해 주세요.';
  if (d.length != 13) return '주민등록번호 13자리를 입력해 주세요.';
  final month = int.tryParse(d.substring(2, 4));
  final day = int.tryParse(d.substring(4, 6));
  if (month == null || day == null || month < 1 || month > 12 || day < 1 || day > 31) {
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
