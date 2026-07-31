import 'package:w0001/util/resident_registration_format.dart';

bool _jsonBool(Object? v) => v == true || v == 1 || v == '1' || v == 'true';

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
    this.registrationCompleteExplicit = false,
  });

  final String? rrnMasked;
  final String? bankAccountMasked;
  final String? bankOwner;
  final String? bankName;
  final bool hasRrn;
  final bool hasBankAccount;
  final bool workerTaxTermAgreed;
  final bool registrationCompleteExplicit;

  bool get isComplete => hasRrn && hasBankAccount && workerTaxTermAgreed;

  /// 세무·정산 등록 완료 — 서버 플래그 또는 필드·약관 이력 조합.
  bool isRegistrationComplete({bool hasTaxAgreementHistory = false}) {
    if (registrationCompleteExplicit) return true;
    return hasRrn &&
        hasBankAccount &&
        (workerTaxTermAgreed || hasTaxAgreementHistory);
  }

  factory UserPrivateRead.fromJson(Map<String, dynamic> json) {
    final rrnMasked = _opt(json['rrn_masked'] ?? json['rrnMasked']);
    final bankMasked =
        _opt(json['bank_account_masked'] ?? json['bankAccountMasked']);
    final hasRrn = _jsonBool(json['has_rrn'] ?? json['hasRrn']) ||
        (rrnMasked != null && rrnMasked.isNotEmpty);
    final hasBank =
        _jsonBool(json['has_bank_account'] ?? json['hasBankAccount']) ||
            (bankMasked != null && bankMasked.isNotEmpty);
    final taxAgreed = _jsonBool(
      json['worker_tax_term_agreed'] ??
          json['workerTaxTermAgreed'] ??
          json['worker_tax_agreed'] ??
          json['workerTaxAgreed'],
    );
    final explicitComplete = _jsonBool(
      json['is_complete'] ??
          json['isComplete'] ??
          json['registration_complete'] ??
          json['registrationComplete'] ??
          json['registered'],
    );
    return UserPrivateRead(
      rrnMasked: rrnMasked,
      bankAccountMasked: bankMasked,
      bankOwner: _opt(json['bank_owner'] ?? json['bankOwner']),
      bankName: _opt(json['bank_name'] ?? json['bankName']),
      hasRrn: hasRrn,
      hasBankAccount: hasBank,
      workerTaxTermAgreed: taxAgreed,
      registrationCompleteExplicit: explicitComplete,
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
