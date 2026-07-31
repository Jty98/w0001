import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';
import 'package:w0001/util/funtions.dart' show normalizeToIsoDateString;

/// 스코프 조회 결과에 등장한 pid·hid만 단건 GET으로 모은다.
/// (전체 places/humans list 대신 N≪ 고유 id 수만큼만 요청)
Future<Map<int, PlaceRead>> loadPlaceMapForPids(
  SuperAdminRemoteRepository remote,
  Iterable<int> pids,
) async {
  final out = <int, PlaceRead>{};
  for (final pid in pids.toSet()) {
    if (pid <= 0) continue;
    try {
      out[pid] = await remote.placeGet(pid);
    } catch (_) {}
  }
  return out;
}

Future<Map<int, HumanRead>> loadHumanMapForHids(
  SuperAdminRemoteRepository remote,
  Iterable<int> hids,
) async {
  final uniqueHids = hids.toSet().where((hid) => hid > 0).toList();

  if (uniqueHids.isEmpty) return {};

  print('🔄 [loadHumanMapForHids] ${uniqueHids.length}명 조회 시작 (배치 API)');
  final startTime = DateTime.now();

  try {
    // ✅ 배치 API로 한 번에 조회 (최대 200명씩)
    final batchSize = 200;
    final batches = <List<int>>[];

    for (var i = 0; i < uniqueHids.length; i += batchSize) {
      final end = (i + batchSize < uniqueHids.length)
          ? i + batchSize
          : uniqueHids.length;
      batches.add(uniqueHids.sublist(i, end));
    }

    print('   → ${batches.length}개 배치로 분할 (각 최대 200명)');

    // 여러 배치를 병렬로 조회
    final batchResults = await Future.wait(
      batches.map((batch) => remote.humanGetBatch(batch)),
    );

    // 결과 병합
    final results = batchResults.expand((list) => list).toList();

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    print(
        '✅ [loadHumanMapForHids] 배치 조회 완료: ${duration}ms, ${results.length}/${uniqueHids.length}명 성공');

    final out = <int, HumanRead>{};
    for (final human in results) {
      out[human.hid] = human;
    }

    return out;
  } catch (e) {
    print('❌ [loadHumanMapForHids] 배치 조회 실패: $e');
    print('⚠️ [loadHumanMapForHids] Fallback: 개별 조회 (병렬)로 전환...');

    // Fallback: 개별 조회 (병렬)
    final results = await Future.wait(
      uniqueHids.map((hid) async {
        try {
          return await remote.humanGet(hid);
        } catch (e) {
          print('⚠️ [loadHumanMapForHids] HID $hid 조회 실패: $e');
          return null;
        }
      }),
    );

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    final successCount = results.where((r) => r != null).length;
    print(
        '✅ [loadHumanMapForHids] Fallback 완료: ${duration}ms, ${successCount}/${uniqueHids.length}명 성공');

    final out = <int, HumanRead>{};
    for (var i = 0; i < uniqueHids.length; i++) {
      final result = results[i];
      if (result != null) {
        out[uniqueHids[i]] = result;
      }
    }

    return out;
  }
}

/// 자재비 API는 `pid` 필수 — 현장별로 하루 스코프 조회 후 합친다.
Future<List<MaterialCostRead>> loadMaterialCostsForPlacesOnDay(
  SuperAdminRemoteRepository remote,
  DateTime day,
  Iterable<int> pids,
) async {
  final baseQ = listQueryForSingleDay(day);
  final out = <MaterialCostRead>[];
  for (final pid in pids.toSet()) {
    if (pid <= 0) continue;
    try {
      final rows = await remote.materialCostsQuery(
        ListQuery(
          pid: pid,
          from: baseQ.from,
          to: baseQ.to,
          limit: baseQ.limit,
        ),
      );
      out.addAll(rows);
    } catch (_) {}
  }
  return out;
}

Map<String, PlaceWorkDayRead> buildPlaceWorkDayByKey(
  Iterable<PlaceWorkDayRead> pwdList,
) {
  final pwdByKey = <String, PlaceWorkDayRead>{};
  for (final pwd in pwdList) {
    final k = '${pwd.hid}|${pwd.pid}|${normalizeToIsoDateString(pwd.workdate)}';
    final prev = pwdByKey[k];
    if (prev == null ||
        (prev.workrole.trim().isEmpty && pwd.workrole.trim().isNotEmpty)) {
      pwdByKey[k] = pwd;
    }
  }
  return pwdByKey;
}
