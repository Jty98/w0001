import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/user_private_models.dart';
import 'package:w0001/util/api_endpoint.dart';

final class UserPrivateRemoteApi {
  UserPrivateRemoteApi(this._http);

  final AppHttpClient _http;

  Future<UserPrivateRead> getWorkerPrivate(String uid) async {
    final res = await _http.get<dynamic>(ApiEndpoint.workersUidPrivate(uid));
    return UserPrivateRead.fromJson(_unwrapPrivatePayload(res.data));
  }

  Future<UserPrivateRead> getMine() async {
    final res = await _http.get<dynamic>(ApiEndpoint.usersMePrivate);
    return UserPrivateRead.fromJson(_unwrapPrivatePayload(res.data));
  }

  /// 관리자 — 작업자 주민번호 전체 조회 (`POST /workers/{uid}/private/rrn/reveal`).
  Future<String> revealWorkerRrn({
    required String uid,
    required String reason,
  }) async {
    final res = await _http.post<dynamic>(
      ApiEndpoint.workersUidPrivateRrnReveal(uid),
      data: <String, dynamic>{'reason': reason.trim()},
    );
    return _extractRevealedValue(res.data, ['rrn', 'value', 'revealed_value']);
  }

  /// 관리자 — 작업자 계좌 전체 조회 (`POST /workers/{uid}/private/bank/reveal`).
  Future<String> revealWorkerBankAccount({
    required String uid,
    required String reason,
  }) async {
    final res = await _http.post<dynamic>(
      ApiEndpoint.workersUidPrivateBankReveal(uid),
      data: <String, dynamic>{'reason': reason.trim()},
    );
    return _extractRevealedValue(
      res.data,
      ['bank_account', 'bankAccount', 'value', 'revealed_value'],
    );
  }

  /// 관리자 — 작업자 인증 연락처 전체 조회.
  Future<String> revealWorkerPhone({
    required String uid,
    required String reason,
  }) async {
    final res = await _http.post<dynamic>(
      ApiEndpoint.workersUidPrivatePhoneReveal(uid),
      data: <String, dynamic>{'reason': reason.trim()},
    );
    return _extractRevealedValue(
      res.data,
      ['phone', 'linked_phone', 'linkedPhone', 'value', 'revealed_value'],
    );
  }

  Future<UserPrivateRead> patchMine(Map<String, dynamic> body) async {
    final res = await _http.patch<dynamic>(
      ApiEndpoint.usersMePrivate,
      data: body,
    );
    return UserPrivateRead.fromJson(_unwrapPrivatePayload(res.data));
  }

  /// 관리자 — 작업자 세무·정산 정보 수정 (`PATCH /workers/{uid}/private`).
  Future<UserPrivateRead> patchWorkerPrivate(
    String uid,
    Map<String, dynamic> body,
  ) async {
    final res = await _http.patch<dynamic>(
      ApiEndpoint.workersUidPrivate(uid),
      data: body,
    );
    return UserPrivateRead.fromJson(_unwrapPrivatePayload(res.data));
  }
}

Map<String, dynamic> _unwrapPrivatePayload(Object? data) {
  if (data is! Map) {
    throw const FormatException('고위험 정보 응답 형식이 올바르지 않습니다.');
  }
  var m = Map<String, dynamic>.from(data);
  for (final key in ['data', 'user', 'private', 'result']) {
    final inner = m[key];
    if (inner is Map) {
      m = Map<String, dynamic>.from(inner);
      break;
    }
  }
  return m;
}

String _extractRevealedValue(Object? data, List<String> keys) {
  if (data is! Map) {
    throw const FormatException('민감정보 조회 응답 형식이 올바르지 않습니다.');
  }
  final m = Map<String, dynamic>.from(data);
  for (final k in keys) {
    final v = m[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  throw const FormatException('민감정보 조회 응답에 값이 없습니다.');
}
