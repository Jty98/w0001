import 'dart:convert';

/// `name:홍길동#number:010…` 형태 인력 키 — URL `#` 프래그먼트 충돌을 피하기 위해 base64url 사용.
String encodeWorkCostHumanRouteKey(String uniqueHuman) =>
    base64Url.encode(utf8.encode(uniqueHuman));

String decodeWorkCostHumanRouteKey(String encoded) {
  try {
    return utf8.decode(base64Url.decode(encoded));
  } catch (_) {
    return '';
  }
}

/// 인력 고유 키에서 이름·연락처 파싱. 실패 시 null.
({String hname, String hnumber})? parseWorkCostHumanKey(String uniqueHuman) {
  if (uniqueHuman.isEmpty) return null;
  final parts = uniqueHuman.split('#');
  if (parts.length < 2) return null;
  final nameSeg = parts[0].split(':');
  final numSeg = parts[1].split(':');
  if (nameSeg.length < 2 || numSeg.length < 2) return null;
  return (hname: nameSeg[1], hnumber: numSeg[1]);
}
