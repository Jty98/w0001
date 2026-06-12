import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/util/phone_number_format.dart';

/// `GET /users/me/account` 응답.
class UserAccountRead {
  const UserAccountRead({
    required this.uid,
    required this.uname,
    required this.role,
    this.phoneMasked,
    this.phoneVerified = false,
  });

  final String uid;
  final String uname;
  final UserRole role;
  final String? phoneMasked;
  final bool phoneVerified;

  factory UserAccountRead.fromJson(Map<String, dynamic> json) {
    final phoneMaskedRaw = json['phone_masked'] ?? json['phoneMasked'];
    final phoneVerifiedRaw = json['phone_verified'] ?? json['phoneVerified'];

    return UserAccountRead(
      uid: json['uid'] as String,
      uname: json['uname'] as String,
      role: UserRole.parse(json['role'] as String),
      phoneMasked: phoneMaskedRaw is String ? phoneMaskedRaw.trim() : null,
      phoneVerified: phoneVerifiedRaw == true,
    );
  }
}

/// `PATCH /users/me/account` 요청 본문.
Map<String, dynamic> userAccountPatchBody({
  String? uname,
  String? currentPassword,
  String? newPassword,
  String? phone,
  String? phoneVerificationToken,
}) {
  final body = <String, dynamic>{};
  final name = uname?.trim() ?? '';
  if (name.isNotEmpty) body['uname'] = name;
  final current = currentPassword?.trim() ?? '';
  if (current.isNotEmpty) body['current_password'] = current;
  final next = newPassword?.trim() ?? '';
  if (next.isNotEmpty) body['new_password'] = next;
  final phoneNorm = phone == null ? '' : normalizeKoreanMobilePhone(phone);
  if (phoneNorm.isNotEmpty) body['phone'] = phoneNorm;
  final token = phoneVerificationToken?.trim() ?? '';
  if (token.isNotEmpty) body['phone_verification_token'] = token;
  return body;
}
