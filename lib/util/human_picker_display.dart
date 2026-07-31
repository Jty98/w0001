import 'package:w0001/util/resident_registration_format.dart';

/// 인력 선택 시트 부제 — 주민번호 앞 6자리·마스킹 뒷자리만 표시.
String humanPickerRrnSubtitle(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return '';

  if (v.contains('*')) {
    final (front, back) = splitResidentRegistrationDisplay(v);
    if (front.isNotEmpty && back.isNotEmpty) {
      return joinResidentRegistrationParts(front, back);
    }
    return v;
  }

  final digits = normalizeResidentRegistrationNumber(v);
  if (digits.length >= 6) {
    final front = digits.substring(0, 6);
    return '$front-*******';
  }
  return v;
}
