import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/util/phone_number_format.dart';

/// 앱 가입·본인인증으로 등록된 연락처 (`linked_phone`, 마스킹 가능).
const kHumanVerifiedPhoneLabel = '연락처';

/// 관리자가 인력 관리에서 직접 입력하는 연락처 (`hphone`).
const kHumanManualPhoneLabel = '연락처';

String? humanVerifiedPhone(HumanModel human) {
  final v = human.linkedPhone?.trim();
  if (v == null || v.isEmpty) return null;
  return v;
}

String? humanManualPhone(HumanModel human) {
  final v = human.hphone?.trim();
  if (v == null || v.isEmpty) return null;
  if (isMaskedPhone(v)) return v;
  return formatKoreanMobilePhoneDisplay(v);
}

bool humanHasAnyContact(HumanModel human) =>
    humanVerifiedPhone(human) != null || humanManualPhone(human) != null;
