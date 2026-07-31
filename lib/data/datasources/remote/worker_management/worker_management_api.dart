import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/worker_rank_wage_settings.dart';
import 'package:w0001/util/api_endpoint.dart';

/// 관리자 전용: 작업자 메모·평가, 트러블 페어 (`admin` / `super_admin`).
final class WorkerManagementRemoteApi {
  WorkerManagementRemoteApi(this._http);

  final AppHttpClient _http;

  Future<List<WorkerMgmtNoteRead>> listNotes(int workerHid) async {
    final page = await listNotesPage(workerHid);
    return page.items;
  }

  Future<PagedResult<WorkerMgmtNoteRead>> listNotesPage(
    int workerHid, {
    int limit = kListPageSize,
    String? cursor,
  }) async {
    final q = <String, dynamic>{'limit': limit};
    final c = cursor?.trim();
    if (c != null && c.isNotEmpty) q['cursor'] = c;
    final r = await _http.get<dynamic>(
      ApiEndpoint.workerManagementNotesHid(workerHid),
      queryParameters: q,
    );
    final page = saParsePagedList(r.data, WorkerMgmtNoteRead.fromJson);
    return page.copyWith(items: _filterAndSortNotes(page.items));
  }

  List<WorkerMgmtNoteRead> _filterAndSortNotes(List<WorkerMgmtNoteRead> list) {
    final out = list.where((n) => n.hasMemoText).toList()
      ..sort((a, b) => (b.noteId ?? 0).compareTo(a.noteId ?? 0));
    return out;
  }

  /// 서버 스펙: `worker_hid`, `note_type` (`memo`|`evaluation`), `memo`, 선택 `rating`.
  Future<WorkerMgmtNoteRead> createNote({
    required int workerHid,
    required String noteType,
    required String memo,
    int? rating,
  }) async {
    final body = <String, dynamic>{
      'worker_hid': workerHid,
      'note_type': noteType,
      'memo': memo.trim(),
    };
    if (rating != null) body['rating'] = rating;

    final r = await _http.post<dynamic>(
      ApiEndpoint.workerManagementNotes,
      data: body,
    );
    final raw = r.data;
    if (raw == null || (raw is String && raw.trim().isEmpty)) {
      return WorkerMgmtNoteRead(
        noteType: noteType,
        memo: memo.trim(),
        rating: rating,
      );
    }
    try {
      return WorkerMgmtNoteRead.fromJson(saParseObject(raw));
    } catch (_) {
      return WorkerMgmtNoteRead(
        noteType: noteType,
        memo: memo.trim(),
        rating: rating,
      );
    }
  }

  Future<List<WorkerMgmtConflictRead>> listConflicts({
    bool activeOnly = true,
  }) async {
    final out = <WorkerMgmtConflictRead>[];
    String? cursor;
    var guard = 0;
    while (guard++ < 100) {
      final page = await listConflictsPage(
        activeOnly: activeOnly,
        cursor: cursor,
      );
      out.addAll(page.items);
      if (!page.canLoadMore) break;
      cursor = page.nextCursor!.trim();
    }
    return out;
  }

  Future<PagedResult<WorkerMgmtConflictRead>> listConflictsPage({
    bool activeOnly = true,
    int limit = kListPageSize,
    String? cursor,
  }) async {
    final q = <String, dynamic>{
      'active_only': activeOnly ? 'true' : 'false',
      'limit': limit,
    };
    final c = cursor?.trim();
    if (c != null && c.isNotEmpty) q['cursor'] = c;
    final r = await _http.get<dynamic>(
      ApiEndpoint.workerManagementConflicts,
      queryParameters: q,
    );
    final page = saParsePagedList(r.data, WorkerMgmtConflictRead.fromJson);
    final items = page.items
        .where((c) => c.isValid && (activeOnly ? c.active : true))
        .toList();
    return page.copyWith(items: items);
  }

  /// 동일 pair 재등록 시 서버에서 업데이트.
  Future<WorkerMgmtConflictRead> upsertConflict({
    required int workerAHid,
    required int workerBHid,
    int severity = 2,
    String note = '',
    bool active = true,
  }) async {
    final a = workerAHid < workerBHid ? workerAHid : workerBHid;
    final b = workerAHid < workerBHid ? workerBHid : workerAHid;
    final r = await _http.post<dynamic>(
      ApiEndpoint.workerManagementConflicts,
      data: <String, dynamic>{
        'worker_a_hid': a,
        'worker_b_hid': b,
        'severity': severity,
        'note': note.trim(),
        'active': active,
      },
    );
    final raw = r.data;
    if (raw == null || (raw is String && raw.trim().isEmpty)) {
      return WorkerMgmtConflictRead(
        workerAHid: a,
        workerBHid: b,
        severity: severity,
        note: note.trim(),
        active: active,
      );
    }
    try {
      return WorkerMgmtConflictRead.fromJson(saParseObject(raw));
    } catch (_) {
      return WorkerMgmtConflictRead(
        workerAHid: a,
        workerBHid: b,
        severity: severity,
        note: note.trim(),
        active: active,
      );
    }
  }

  /// [DELETE /worker-management/conflicts/:pair_id] — 성공 시 204.
  Future<void> deleteConflict(int pairId) async {
    await _http.delete<dynamic>(
      ApiEndpoint.workerManagementConflictPairId(pairId),
    );
  }

  static Map<String, dynamic> _parseRankWagesBody(dynamic raw) {
    final root = saParseObject(raw);
    if (root.containsKey('wages_by_rank') || root.containsKey('wagesByRank')) {
      return root;
    }
    final data = root['data'];
    if (data is Map) {
      final inner = Map<String, dynamic>.from(data);
      if (inner.containsKey('wages_by_rank') ||
          inner.containsKey('wagesByRank')) {
        return inner;
      }
    }
    return root;
  }

  /// [GET /worker-management/rank-wages] — 서버 미구현 시 404.
  Future<WorkerRankWageSettings> getRankWages() async {
    final r = await _http.get<dynamic>(ApiEndpoint.workerManagementRankWages);
    return WorkerRankWageSettings.fromJson(_parseRankWagesBody(r.data));
  }

  /// [PUT /worker-management/rank-wages] — 전체 교체.
  Future<WorkerRankWageSettings> putRankWages(
    WorkerRankWageSettings settings,
  ) async {
    final body = settings.copyWith(
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final r = await _http.put<dynamic>(
      ApiEndpoint.workerManagementRankWages,
      data: body.toJson(),
    );
    return WorkerRankWageSettings.fromJson(_parseRankWagesBody(r.data));
  }
}
