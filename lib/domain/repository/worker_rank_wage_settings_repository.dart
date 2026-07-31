import 'package:w0001/data/model/worker_rank_wage_settings.dart';

abstract class WorkerRankWageSettingsRepository {
  /// 메모리 캐시 — [getSettings]·저장·동기화 후 즉시 조회 가능.
  WorkerRankWageSettings get cachedSettings;

  int? cachedWageForRank(String rank);

  Future<WorkerRankWageSettings> getSettings();

  Future<WorkerRankWageSettings> saveSettings(WorkerRankWageSettings settings);

  /// 서버에 엔드포인트가 있으면 최신값으로 로컬을 갱신한다.
  /// 404면 로컬 스냅샷을 그대로 반환한다.
  Future<WorkerRankWageSettings> syncFromServer();

  /// 로그아웃·계정 전환 시 로컬·메모리 캐시를 비운다.
  Future<void> clearLocalCache();
}
