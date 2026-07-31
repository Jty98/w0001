import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/util/api_endpoint.dart';

/// 작업자 공지 API.
///
/// **서버 스펙(권장)** — 백엔드가 맞춰 주면 그대로 동작합니다.
///
/// * `GET /worker-announcements/inbox` — 수신함. `scope`, `pid`, `pcomplete` 선택.
/// * `GET /worker-announcements` — 관리 목록. `scope`, `pid`, `pcomplete` 선택.
/// * `GET /worker-announcements/{id}` — 단건(편집 화면용)
/// * `POST /worker-announcements` — 관리자 생성 `{ scope, pid?, title, blocks }`
/// * `PATCH /worker-announcements/{id}` — 관리자 수정
/// * `DELETE /worker-announcements/{id}` — 관리자 삭제
///
/// `blocks`: `[{ "type": "text", "text": "..." }, { "type": "image", "url": "https://..." }]`
final class WorkerAnnouncementsRemoteApi {
  WorkerAnnouncementsRemoteApi(this._http);

  final AppHttpClient _http;

  List<WorkerAnnouncementRead> _mapList(dynamic data) {
    final list = _extractList(data);
    final out = <WorkerAnnouncementRead>[];
    for (final e in list) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final item = WorkerAnnouncementRead.fromJson(_unwrapAnnouncementMap(m));
      if (item.id != 0 || item.title.isNotEmpty || item.blocks.isNotEmpty) {
        out.add(item);
      }
    }
    out.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return out;
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final inner =
          m['data'] ?? m['items'] ?? m['announcements'] ?? m['results'];
      if (inner is List) return inner;
    }
    return const [];
  }

  Map<String, dynamic> _unwrapAnnouncementMap(Map<String, dynamic> m) {
    for (final key in ['announcement', 'item', 'worker_announcement']) {
      final inner = m[key];
      if (inner is Map) {
        return Map<String, dynamic>.from(inner);
      }
    }
    return m;
  }

  Map<String, dynamic> _parseOneObject(dynamic data) {
    if (data is! Map) return saParseObject(data);
    final m = Map<String, dynamic>.from(data);
    final inner = m['data'] ?? m['result'];
    if (inner is Map) {
      return _unwrapAnnouncementMap(Map<String, dynamic>.from(inner));
    }
    return _unwrapAnnouncementMap(m);
  }

  /// 수신함 (작업자·관리자 공통).
  Future<List<WorkerAnnouncementRead>> inbox({int? pid}) async {
    final page = await inboxPage(pid: pid);
    return page.items;
  }

  Future<PagedResult<WorkerAnnouncementRead>> inboxPage({
    int? pid,
    WorkerAnnouncementScope? scope,
    int? pcomplete,
    int limit = kListPageSize,
    String? cursor,
  }) async {
    final q = <String, dynamic>{'limit': limit};
    if (pid != null) q['pid'] = pid;
    if (scope != null) q['scope'] = scope.wireValue;
    if (pcomplete != null) q['pcomplete'] = pcomplete;
    final c = cursor?.trim();
    if (c != null && c.isNotEmpty) q['cursor'] = c;
    final r = await _http.get<dynamic>(
      ApiEndpoint.workerAnnouncementsInbox,
      queryParameters: q,
    );
    return _parsePaged(r.data);
  }

  /// 관리자: 전체 공지 목록.
  Future<List<WorkerAnnouncementRead>> manageList() async {
    final page = await manageListPage();
    return page.items;
  }

  Future<PagedResult<WorkerAnnouncementRead>> manageListPage({
    int? pid,
    WorkerAnnouncementScope? scope,
    int? pcomplete,
    int limit = kListPageSize,
    String? cursor,
  }) async {
    final q = <String, dynamic>{'limit': limit};
    if (pid != null) q['pid'] = pid;
    if (scope != null) q['scope'] = scope.wireValue;
    if (pcomplete != null) q['pcomplete'] = pcomplete;
    final c = cursor?.trim();
    if (c != null && c.isNotEmpty) q['cursor'] = c;
    final r = await _http.get<dynamic>(
      ApiEndpoint.workerAnnouncements,
      queryParameters: q,
    );
    return _parsePaged(r.data);
  }

  PagedResult<WorkerAnnouncementRead> _parsePaged(dynamic data) {
    final page = saParsePagedList(
      data,
      (m) => WorkerAnnouncementRead.fromJson(_unwrapAnnouncementMap(m)),
    );
    final items = page.items
        .where((a) => a.id != 0 || a.title.isNotEmpty || a.blocks.isNotEmpty)
        .toList();
    return PagedResult(
      items: _sortAnnouncements(items),
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      totalCount: page.totalCount,
    );
  }

  List<WorkerAnnouncementRead> _sortAnnouncements(
      List<WorkerAnnouncementRead> out) {
    out.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return out;
  }

  Future<WorkerAnnouncementRead> getById(int id) async {
    final r = await _http.get<dynamic>(ApiEndpoint.workerAnnouncementsId(id));
    return WorkerAnnouncementRead.fromJson(_parseOneObject(r.data));
  }

  Future<WorkerAnnouncementRead> create(
      WorkerAnnouncementWriteBody body) async {
    final r = await _http.post<dynamic>(
      ApiEndpoint.workerAnnouncements,
      data: body.toJson(),
    );
    return WorkerAnnouncementRead.fromJson(_parseOneObject(r.data));
  }

  Future<WorkerAnnouncementRead> patch(
    int id,
    WorkerAnnouncementWriteBody body,
  ) async {
    final r = await _http.patch<dynamic>(
      ApiEndpoint.workerAnnouncementsId(id),
      data: body.toJson(),
    );
    return WorkerAnnouncementRead.fromJson(_parseOneObject(r.data));
  }

  Future<void> delete(int id) async {
    await _http.delete<dynamic>(ApiEndpoint.workerAnnouncementsId(id));
  }

  /// 공지 고정.
  Future<WorkerAnnouncementRead> pin(int id) async {
    final r = await _http.post<dynamic>(
      '${ApiEndpoint.workerAnnouncementsId(id)}/pin',
      data: <String, dynamic>{},
    );
    return WorkerAnnouncementRead.fromJson(_parseOneObject(r.data));
  }

  /// 공지 고정 해제.
  Future<WorkerAnnouncementRead> unpin(int id) async {
    final r = await _http.delete<dynamic>(
      '${ApiEndpoint.workerAnnouncementsId(id)}/pin',
    );
    return WorkerAnnouncementRead.fromJson(_parseOneObject(r.data));
  }
}
