import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/util/api_endpoint.dart';

/// 작업자 공지 API.
///
/// **서버 스펙(권장)** — 백엔드가 맞춰 주면 그대로 동작합니다.
///
/// * `GET /worker-announcements/inbox` — 로그인 사용자 기준 수신 가능 공지
///   (전체 공지 + 내가 볼 수 있는 현장 공지). 선택 쿼리 `pid`로 특정 현장만 필터.
/// * `GET /worker-announcements` — `admin`/`super_admin` 전용, 등록된 공지 전체 목록
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
      final item = WorkerAnnouncementRead.fromJson(m);
      if (item.id != 0 || item.title.isNotEmpty || item.blocks.isNotEmpty) {
        out.add(item);
      }
    }
    out.sort((a, b) {
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

  /// 수신함 (작업자·관리자 공통).
  Future<List<WorkerAnnouncementRead>> inbox({int? pid}) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.workerAnnouncementsInbox,
      queryParameters:
          pid == null ? null : <String, dynamic>{'pid': pid},
    );
    return _mapList(r.data);
  }

  /// 관리자: 전체 공지 목록.
  Future<List<WorkerAnnouncementRead>> manageList() async {
    final r = await _http.get<dynamic>(ApiEndpoint.workerAnnouncements);
    return _mapList(r.data);
  }

  Future<WorkerAnnouncementRead> getById(int id) async {
    final r = await _http.get<dynamic>(ApiEndpoint.workerAnnouncementsId(id));
    return WorkerAnnouncementRead.fromJson(saParseObject(r.data));
  }

  Future<WorkerAnnouncementRead> create(WorkerAnnouncementWriteBody body) async {
    final r = await _http.post<dynamic>(
      ApiEndpoint.workerAnnouncements,
      data: body.toJson(),
    );
    return WorkerAnnouncementRead.fromJson(saParseObject(r.data));
  }

  Future<WorkerAnnouncementRead> patch(
    int id,
    WorkerAnnouncementWriteBody body,
  ) async {
    final r = await _http.patch<dynamic>(
      ApiEndpoint.workerAnnouncementsId(id),
      data: body.toJson(),
    );
    return WorkerAnnouncementRead.fromJson(saParseObject(r.data));
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
    return WorkerAnnouncementRead.fromJson(saParseObject(r.data));
  }

  /// 공지 고정 해제.
  Future<WorkerAnnouncementRead> unpin(int id) async {
    final r = await _http.delete<dynamic>(
      '${ApiEndpoint.workerAnnouncementsId(id)}/pin',
    );
    return WorkerAnnouncementRead.fromJson(saParseObject(r.data));
  }
}
