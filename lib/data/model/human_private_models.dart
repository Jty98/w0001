import 'package:w0001/util/phone_number_format.dart';
import 'package:w0001/util/resident_registration_format.dart';

/// `GET /humans/{hid}/private` — 마스킹된 인력 민감정보.
class HumanPrivateRead {
  const HumanPrivateRead({
    this.rrnMasked,
    this.hphoneMasked,
    this.linkedPhoneMasked,
    this.bankAccountMasked,
    this.bankOwner,
    this.bankName,
    this.hasRrn = false,
    this.hasHphone = false,
    this.hasLinkedPhone = false,
    this.hasBankAccount = false,
  });

  final String? rrnMasked;
  final String? hphoneMasked;
  final String? linkedPhoneMasked;
  final String? bankAccountMasked;
  final String? bankOwner;
  final String? bankName;
  final bool hasRrn;
  final bool hasHphone;
  final bool hasLinkedPhone;
  final bool hasBankAccount;

  factory HumanPrivateRead.fromJson(Map<String, dynamic> json) {
    final rrnMasked = _opt(json['rrn_masked'] ??
        json['rrnMasked'] ??
        json['hnumber_masked'] ??
        json['hnumberMasked']);
    final hphoneMasked =
        _opt(json['hphone_masked'] ?? json['hphoneMasked'] ?? json['hphone']);
    final linkedPhoneMasked = _opt(json['linked_phone_masked'] ??
        json['linkedPhoneMasked'] ??
        json['linked_phone'] ??
        json['linkedPhone']);
    final bankMasked =
        _opt(json['bank_account_masked'] ?? json['bankAccountMasked']);

    return HumanPrivateRead(
      rrnMasked: rrnMasked,
      hphoneMasked: hphoneMasked,
      linkedPhoneMasked: linkedPhoneMasked,
      bankAccountMasked: bankMasked,
      bankOwner: _opt(json['bank_owner'] ?? json['bankOwner']),
      bankName: _opt(json['bank_name'] ?? json['bankName']),
      hasRrn: json['has_rrn'] == true ||
          json['hasRrn'] == true ||
          (rrnMasked?.isNotEmpty ?? false),
      hasHphone: json['has_hphone'] == true ||
          json['hasHphone'] == true ||
          (hphoneMasked?.isNotEmpty ?? false),
      hasLinkedPhone: json['has_linked_phone'] == true ||
          json['hasLinkedPhone'] == true ||
          (linkedPhoneMasked?.isNotEmpty ?? false),
      hasBankAccount: json['has_bank_account'] == true ||
          json['hasBankAccount'] == true ||
          (bankMasked?.isNotEmpty ?? false),
    );
  }

  /// 목록·단건 [HumanRead] 값으로 폴백 (private API 미구현 시).
  factory HumanPrivateRead.fromHumanFields({
    required String hnumber,
    String? hphone,
    String? linkedPhone,
  }) {
    final rrn = hnumber.trim();
    final manual = hphone?.trim();
    final linked = linkedPhone?.trim();
    return HumanPrivateRead(
      rrnMasked: rrn.isNotEmpty ? rrn : null,
      hphoneMasked: manual != null && manual.isNotEmpty ? manual : null,
      linkedPhoneMasked: linked != null && linked.isNotEmpty ? linked : null,
      hasRrn: rrn.isNotEmpty,
      hasHphone: manual != null && manual.isNotEmpty,
      hasLinkedPhone: linked != null && linked.isNotEmpty,
    );
  }
}

String? _opt(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

/// `PATCH /humans/{hid}/private`
Map<String, dynamic> humanPrivatePatchBody({
  String? rrn,
  String? bankAccount,
  String? bankOwner,
  String? bankName,
  String? hphone,
}) {
  final body = <String, dynamic>{};
  final rrnNorm = rrn == null ? '' : formatResidentRegistrationDisplay(rrn);
  if (rrnNorm.isNotEmpty) body['rrn'] = rrnNorm;
  final account = bankAccount?.replaceAll(RegExp(r'\D'), '').trim() ?? '';
  if (account.isNotEmpty) body['bank_account'] = account;
  final owner = bankOwner?.trim() ?? '';
  if (owner.isNotEmpty) body['bank_owner'] = owner;
  final bank = bankName?.trim() ?? '';
  if (bank.isNotEmpty) body['bank_name'] = bank;
  final phone = hphone?.trim() ?? '';
  if (phone.isNotEmpty && !isMaskedPhone(phone)) {
    body['hphone'] = formatKoreanMobilePhoneDisplay(phone);
  }
  return body;
}
