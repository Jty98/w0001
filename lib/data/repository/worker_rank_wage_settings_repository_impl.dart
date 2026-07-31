import 'package:w0001/data/datasources/local/worker_rank_wage_settings_storage.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/worker_management/worker_management_api.dart';
import 'package:w0001/data/model/worker_rank_wage_settings.dart';
import 'package:w0001/domain/repository/worker_rank_wage_settings_repository.dart';

class WorkerRankWageSettingsRepositoryImpl
    implements WorkerRankWageSettingsRepository {
  WorkerRankWageSettingsRepositoryImpl(this._api, this._storage);

  final WorkerManagementRemoteApi _api;
  final WorkerRankWageSettingsStorage _storage;

  WorkerRankWageSettings _cache = WorkerRankWageSettings.empty();
  var _cacheLoaded = false;

  void _updateCache(WorkerRankWageSettings settings) {
    _cache = settings;
    _cacheLoaded = true;
  }

  /// 서버가 빈 응답을 줄 때 로컬에 있던 설정을 지우지 않는다.
  WorkerRankWageSettings _preferLocalWhenRemoteEmpty(
    WorkerRankWageSettings remote,
    WorkerRankWageSettings local,
  ) {
    final remoteHasWages = remote.wagesByRank.values.any((wage) => wage > 0);
    final localHasWages = local.wagesByRank.values.any((wage) => wage > 0);
    if (!remoteHasWages && localHasWages) return local;

    final remoteHasRanks =
        remote.rankOrder.isNotEmpty || remote.wagesByRank.isNotEmpty;
    final localHasRanks =
        local.rankOrder.isNotEmpty || local.wagesByRank.isNotEmpty;
    if (!remoteHasRanks && localHasRanks) return local;

    return remote;
  }

  @override
  WorkerRankWageSettings get cachedSettings => _cache;

  @override
  int? cachedWageForRank(String rank) => _cache.wageForRank(rank);

  Future<void> _ensureLoadedFromStorage() async {
    if (_cacheLoaded) return;
    _updateCache(await _storage.load());
  }

  @override
  Future<WorkerRankWageSettings> getSettings() async {
    await _ensureLoadedFromStorage();
    return _cache;
  }

  @override
  Future<WorkerRankWageSettings> saveSettings(
    WorkerRankWageSettings settings,
  ) async {
    final stamped = settings.copyWith(
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _storage.save(stamped);
    _updateCache(stamped);

    try {
      final remote = await _api.putRankWages(stamped);
      await _storage.save(remote);
      _updateCache(remote);
      return remote;
    } on HttpStatusException catch (e) {
      if (e.statusCode == 404) return stamped;
      rethrow;
    }
  }

  @override
  Future<WorkerRankWageSettings> syncFromServer() async {
    try {
      final remote = await _api.getRankWages();
      await _ensureLoadedFromStorage();
      final resolved = _preferLocalWhenRemoteEmpty(remote, _cache);
      await _storage.save(resolved);
      _updateCache(resolved);
      return resolved;
    } on HttpStatusException catch (e) {
      if (e.statusCode == 404) {
        await _ensureLoadedFromStorage();
        return _cache;
      }
      rethrow;
    }
  }

  @override
  Future<void> clearLocalCache() async {
    await _storage.clear();
    _cache = WorkerRankWageSettings.empty();
    _cacheLoaded = false;
  }
}
