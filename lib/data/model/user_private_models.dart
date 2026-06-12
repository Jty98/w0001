import 'package:w0001/util/resident_registration_format.dart';

/// `GET /users/me/private` — 마스킹된 고위험 정보.
class UserPrivateRead {
  const UserPrivateRead({
    this.rrnMasked,
    this.bankAccountMasked,
    this.bankOwner,
    this.bankName,
    this.hasRrn = false,
    this.hasBankAccount = false,
    this.workerTaxTermAgreed = false,
  });

  final String? rrnMasked;
  final String? bankAccountMasked;
  final String? bankOwner;
  final String? bankName;
  final bool hasRrn;
  final bool hasBankAccount;
  final bool workerTaxTermAgreed;

  bool get isComplete =>
      hasRrn && hasBankAccount && workerTaxTermAgreed;

  factory UserPrivateRead.fromJson(Map<String, dynamic> json) {
    final rrnMasked = _opt(json['rrn_masked'] ?? json['rrnMasked']);
    final bankMasked =
        _opt(json['bank_account_masked'] ?? json['bankAccountMasked']);
    final hasRrn = json['has_rrn'] == true ||
        json['hasRrn'] == true ||
        (rrnMasked != null && rrnMasked.isNotEmpty);
    final hasBank = json['has_bank_account'] == true ||
        json['hasBankAccount'] == true ||
        (bankMasked != null && bankMasked.isNotEmpty);
    return UserPrivateRead(
      rrnMasked: rrnMasked,
      bankAccountMasked: bankMasked,
      bankOwner: _opt(json['bank_owner'] ?? json['bankOwner']),
      bankName: _opt(json['bank_name'] ?? json['bankName']),
      hasRrn: hasRrn,
      hasBankAccount: hasBank,
      workerTaxTermAgreed: json['worker_tax_term_agreed'] == true ||
          json['workerTaxTermAgreed'] == true,
    );
  }
}

/// `PATCH /users/me/private`
Map<String, dynamic> userPrivatePatchBody({
  String? rrn,
  String? bankAccount,
  String? bankOwner,
  String? bankName,
  int? workerTaxTermId,
  String? workerTaxTermVersion,
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
  if (workerTaxTermId != null && workerTaxTermId > 0) {
    body['worker_tax_term_id'] = workerTaxTermId;
  }
  final ver = workerTaxTermVersion?.trim() ?? '';
  if (ver.isNotEmpty) body['worker_tax_term_version'] = ver;
  return body;
}

String? _opt(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}
