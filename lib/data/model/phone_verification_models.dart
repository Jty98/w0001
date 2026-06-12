/// `POST /auth/phone/send-code` 응답.
class PhoneMoStartResponse {
  const PhoneMoStartResponse({
    required this.verificationCode,
    required this.moNumber,
    required this.moNumberDisplay,
    required this.smsBody,
    required this.phoneMasked,
    required this.expiresInSeconds,
    required this.instructions,
    required this.octomoConfigured,
  });

  final String verificationCode;
  final String moNumber;
  final String moNumberDisplay;
  final String smsBody;
  final String phoneMasked;
  final int expiresInSeconds;
  final String instructions;
  final bool octomoConfigured;

  factory PhoneMoStartResponse.fromJson(Map<String, dynamic> json) {
    return PhoneMoStartResponse(
      verificationCode: _str(json['verification_code']),
      moNumber: _str(json['mo_number']),
      moNumberDisplay: _str(json['mo_number_display']),
      smsBody: _str(json['sms_body']),
      phoneMasked: _str(json['phone_masked']),
      expiresInSeconds: _int(json['expires_in_seconds']) ?? 300,
      instructions: _str(json['instructions']),
      octomoConfigured: json['octomo_configured'] == true,
    );
  }
}

/// `POST /auth/phone/verify` 응답.
class PhoneMoVerifyResponse {
  const PhoneMoVerifyResponse({
    required this.verified,
    required this.status,
    required this.message,
    this.phoneVerificationToken,
    this.expiresInSeconds,
  });

  final bool verified;
  final String status;
  final String message;
  final String? phoneVerificationToken;
  final int? expiresInSeconds;

  factory PhoneMoVerifyResponse.fromJson(Map<String, dynamic> json) {
    return PhoneMoVerifyResponse(
      verified: json['verified'] == true,
      status: _str(json['status']),
      message: _str(json['message']),
      phoneVerificationToken: _optStr(json['phone_verification_token']),
      expiresInSeconds: _int(json['expires_in_seconds']),
    );
  }
}

String _str(Object? v) => v?.toString().trim() ?? '';

String? _optStr(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}
