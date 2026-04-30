import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class UsersRemoteApi {
  UsersRemoteApi(this._http);

  final AppHttpClient _http;

  Options _adminActionOptions(String adminActionToken) => Options(
        headers: <String, dynamic>{
          ApiEndpoint.headerAdminActionToken: adminActionToken,
        },
      );

  Future<List<UserRead>> list() async {
    final r = await _http.get<dynamic>(ApiEndpoint.users);
    return saMapList(r.data, userReadFromJson);
  }

  Future<UserRead> get(String uid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.usersUid(uid));
    return userReadFromJson(saParseObject(r.data));
  }

  Future<UserRead> create(UserCreateBody body) async {
    final r = await _http.post<dynamic>(ApiEndpoint.users, data: body.toJson());
    return userReadFromJson(saParseObject(r.data));
  }

  Future<UserRead> patch(String uid, Map<String, dynamic> body) async {
    final r = await _http.patch<dynamic>(ApiEndpoint.usersUid(uid), data: body);
    return userReadFromJson(saParseObject(r.data));
  }

  Future<void> delete(String uid) async {
    await _http.delete<dynamic>(ApiEndpoint.usersUid(uid));
  }

  /// `GET /users/pending` — 승인 대기 ([q] 선택: 이름 부분 검색)
  Future<List<UserRead>> listPending({String? q}) async {
    final qp = <String, dynamic>{};
    final t = q?.trim();
    if (t != null && t.isNotEmpty) qp['q'] = t;
    final r = await _http.get<dynamic>(
      ApiEndpoint.usersPending,
      queryParameters: qp.isEmpty ? null : qp,
    );
    return saMapList(r.data, userReadFromJson);
  }

  /// `GET /users/search` — role / approval_status / is_active / q 조합
  Future<List<UserRead>> search({
    String? role,
    String? approvalStatus,
    bool? isActive,
    String? q,
  }) async {
    final m = <String, dynamic>{};
    final rs = role?.trim();
    final ap = approvalStatus?.trim();
    final qq = q?.trim();
    if (rs != null && rs.isNotEmpty) m['role'] = rs;
    if (ap != null && ap.isNotEmpty) m['approval_status'] = ap;
    if (isActive != null) m['is_active'] = isActive;
    if (qq != null && qq.isNotEmpty) m['q'] = qq;
    final r = await _http.get<dynamic>(
      ApiEndpoint.usersSearch,
      queryParameters: m.isEmpty ? null : m,
    );
    return saMapList(r.data, userReadFromJson);
  }

  Future<void> approve(String uid, {String? note}) async {
    await _http.post<dynamic>(
      ApiEndpoint.usersUidApprove(uid),
      data: _optionalNote(note),
    );
  }

  Future<void> reject(String uid, {String? note}) async {
    await _http.post<dynamic>(
      ApiEndpoint.usersUidReject(uid),
      data: _optionalNote(note),
    );
  }

  Future<void> suspend(
    String uid, {
    String? reason,
    required String adminActionToken,
  }) async {
    await _http.post<dynamic>(
      ApiEndpoint.usersUidSuspend(uid),
      data: _optionalReason(reason),
      options: _adminActionOptions(adminActionToken),
    );
  }

  Future<void> activate(String uid) async {
    await _http.post<dynamic>(ApiEndpoint.usersUidActivate(uid));
  }

  /// `admin` / `worker` 만 허용 (서버가 super_admin 변경 차단).
  Future<UserRead> changeRole(
    String uid,
    UserRole role, {
    required String adminActionToken,
  }) async {
    if (role == UserRole.superAdmin) {
      throw ArgumentError('super_admin 역할로 변경할 수 없습니다.');
    }
    final r = await _http.post<dynamic>(
      ApiEndpoint.usersUidRole(uid),
      data: <String, dynamic>{'role': role.wireValue},
      options: _adminActionOptions(adminActionToken),
    );
    final data = r.data;
    if (data is Map<String, dynamic>) {
      return userReadFromJson(data);
    }
    if (data is Map) {
      return userReadFromJson(Map<String, dynamic>.from(data));
    }
    return get(uid);
  }
}

Map<String, dynamic> _optionalNote(String? note) {
  final t = note?.trim();
  if (t == null || t.isEmpty) return <String, dynamic>{};
  return <String, dynamic>{'note': t};
}

Map<String, dynamic> _optionalReason(String? reason) {
  final t = reason?.trim();
  if (t == null || t.isEmpty) return <String, dynamic>{};
  return <String, dynamic>{'reason': t};
}
