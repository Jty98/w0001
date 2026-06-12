import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

/// 관리자 전용: 작업자 메모·평가, 트러블 페어 (`admin` / `super_admin`).
final class WorkerManagementRemoteApi {
  WorkerManagementRemoteApi(this._http);

  final AppHttpClient _http;

  Future<List<WorkerMgmtNoteRead>> listNotes(int workerHid) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.workerManagementNotesHid(workerHid),
    );
    final data = r.data;
    List<dynamic> list = const [];
    if (data is List) {
      list = data;
    } else if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final inner = m['data'] ?? m['notes'];
      if (inner is List) list = inner;
    }
    final out = list
        .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
        .map(WorkerMgmtNoteRead.fromJson)
        .where((n) => n.hasMemoText)
        .toList();
    out.sort((a, b) => (b.noteId ?? 0).compareTo(a.noteId ?? 0));
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
    final r = await _http.get<dynamic>(
      ApiEndpoint.workerManagementConflicts,
      queryParameters: <String, dynamic>{
        'active_only': activeOnly ? 'true' : 'false',
      },
    );
    final data = r.data;
    List<dynamic> list = const [];
    if (data is List) {
      list = data;
    } else if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final inner = m['data'] ?? m['conflicts'];
      if (inner is List) list = inner;
    }
    return list
        .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
        .map(WorkerMgmtConflictRead.fromJson)
        .where((c) => c.isValid && (activeOnly ? c.active : true))
        .toList();
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
}
