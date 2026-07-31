import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/paged_result.dart';
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

  /// `PUT /users/me/fcm-device` — FCM 토큰 upsert (작업자·관리자 JWT).
  ///
  /// 서버 계약: `fcmToken`, `platform`, `deviceId` (camelCase).
  Future<void> putMyFcmDevice({
    required String fcmToken,
    required String platform,
    String deviceId = '',
  }) async {
    final body = <String, dynamic>{
      'fcmToken': fcmToken,
      'platform': platform,
    };
    final device = deviceId.trim();
    if (device.isNotEmpty) {
      body['deviceId'] = device;
    }
    await _http.put<dynamic>(
      ApiEndpoint.usersMeFcmDevice,
      data: body,
    );
  }

  /// `GET /users/me/fcm-device/status` — 등록 여부 확인.
  Future<FcmDeviceStatusRead> getMyFcmDeviceStatus() async {
    final r = await _http.get<dynamic>(ApiEndpoint.usersMeFcmDeviceStatus);
    final data = r.data;
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : throw const FormatException('FCM device status 응답 형식이 올바르지 않습니다.');
    final payload = map['data'] ?? map['result'] ?? map;
    if (payload is! Map) {
      throw const FormatException('FCM device status 응답 형식이 올바르지 않습니다.');
    }
    return FcmDeviceStatusRead.fromJson(Map<String, dynamic>.from(payload));
  }

  /// `GET /users/search` — role / approval_status / is_active / q 조합
  Future<List<UserRead>> search({
    String? role,
    String? approvalStatus,
    bool? isActive,
    String? q,
  }) async {
    final page = await searchPage(
      role: role,
      approvalStatus: approvalStatus,
      isActive: isActive,
      q: q,
    );
    return page.items;
  }

  Future<PagedResult<UserRead>> searchPage({
    String? role,
    String? approvalStatus,
    bool? isActive,
    String? q,
    int limit = kListPageSize,
    String? cursor,
  }) async {
    final m = <String, dynamic>{'limit': limit};
    final rs = role?.trim();
    final ap = approvalStatus?.trim();
    final qq = q?.trim();
    if (rs != null && rs.isNotEmpty) m['role'] = rs;
    if (ap != null && ap.isNotEmpty) m['approval_status'] = ap;
    if (isActive != null) m['is_active'] = isActive;
    if (qq != null && qq.isNotEmpty) m['q'] = qq;
    final c = cursor?.trim();
    if (c != null && c.isNotEmpty) m['cursor'] = c;
    final r = await _http.get<dynamic>(
      ApiEndpoint.usersSearch,
      queryParameters: m,
    );
    return saParsePagedList(r.data, userReadFromJson);
  }

  /// `GET /users/pending` — 승인 대기 ([q] 선택: 이름 부분 검색)
  Future<List<UserRead>> listPending({String? q}) async {
    final page = await pendingPage(q: q);
    return page.items;
  }

  Future<PagedResult<UserRead>> pendingPage({
    String? q,
    int limit = kListPageSize,
    String? cursor,
  }) async {
    final qp = <String, dynamic>{'limit': limit};
    final t = q?.trim();
    if (t != null && t.isNotEmpty) qp['q'] = t;
    final c = cursor?.trim();
    if (c != null && c.isNotEmpty) qp['cursor'] = c;
    final r = await _http.get<dynamic>(
      ApiEndpoint.usersPending,
      queryParameters: qp,
    );
    return saParsePagedList(r.data, userReadFromJson);
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
    if (role != UserRole.admin && role != UserRole.worker) {
      throw ArgumentError('admin 또는 worker 역할만 지정할 수 있습니다.');
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

  /// 여러 인력을 한 번에 조회 (N+1 쿼리 방지)
  Future<List<UserRead>> getBatch(List<int> hids) async {
    if (hids.isEmpty) return [];

    final r = await _http.post<dynamic>(
      '${ApiEndpoint.users}/batch',
      data: {'hids': hids},
    );

    // 서버 응답이 List<UserRead> 형태
    return saMapList(r.data, userReadFromJson);
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
