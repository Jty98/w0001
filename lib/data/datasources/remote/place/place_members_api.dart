import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/place_member_model.dart';
import 'package:w0001/util/api_endpoint.dart';

/// 현장 멤버 관리 API.
final class PlaceMembersApi {
  PlaceMembersApi(this._http);

  final AppHttpClient _http;

  /// 현장 멤버 목록 조회.
  Future<List<PlaceMemberRead>> getPlaceMembers(int pid) async {
    final r = await _http.get<dynamic>(
      '${ApiEndpoint.places}/$pid/members',
    );
    
    final data = r.data;
    final List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final inner = m['data'] ?? m['members'] ?? m['items'];
      if (inner is List) {
        list = inner;
      } else {
        list = [];
      }
    } else {
      list = [];
    }

    final out = <PlaceMemberRead>[];
    for (final e in list) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      out.add(PlaceMemberRead.fromJson(m));
    }
    
    return out;
  }

  /// 작업자 초대.
  Future<PlaceMemberAddResponse> addMember(int pid, String workerUid) async {
    final r = await _http.post<dynamic>(
      '${ApiEndpoint.places}/$pid/members/$workerUid',
      data: <String, dynamic>{},
    );
    return PlaceMemberAddResponse.fromJson(_unwrapMemberEnvelope(r.data));
  }

  /// 작업자 제거.
  Future<PlaceMemberRemoveResponse> removeMember(
    int pid,
    String workerUid,
  ) async {
    final r = await _http.delete<dynamic>(
      '${ApiEndpoint.places}/$pid/members/$workerUid',
    );
    return PlaceMemberRemoveResponse.fromJson(_unwrapMemberEnvelope(r.data));
  }

  /// 목록 API와 동일하게 `{ "data": { ... } }` 래퍼를 벗깁니다.
  static Map<String, dynamic> _unwrapMemberEnvelope(dynamic raw) {
    if (raw == null) return <String, dynamic>{};
    final m = saParseObject(raw);
    final data = m['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    final result = m['result'];
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return m;
  }
}
