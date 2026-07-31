import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/data/model/worker_rank_wage_settings.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';
import 'package:w0001/domain/repository/worker_rank_wage_settings_repository.dart';

class WorkerRankWageSettingsUseCase {
  WorkerRankWageSettingsUseCase(this._settingsRepo, this._remote);

  final WorkerRankWageSettingsRepository _settingsRepo;
  final SuperAdminRemoteRepository _remote;

  Future<WorkerRankWageSettings> getSettings() => _settingsRepo.getSettings();

  Future<WorkerRankWageSettings> saveSettings(
    WorkerRankWageSettings settings,
  ) =>
      _settingsRepo.saveSettings(settings);

  Future<WorkerRankWageSettings> syncFromServer() =>
      _settingsRepo.syncFromServer();

  WorkerRankWageSettings get cachedSettings => _settingsRepo.cachedSettings;

  /// 로컬·메모리 캐시에서 역할별 일당을 즉시 조회한다.
  int? wageForRankSync(String rank) => _settingsRepo.cachedWageForRank(rank);

  /// 로컬 캐시를 먼저 채운 뒤, 백그라운드에서 서버와 동기화한다.
  Future<void> warmUp({bool syncRemote = true}) async {
    await _settingsRepo.getSettings();
    if (!syncRemote) return;
    try {
      await _settingsRepo.syncFromServer();
    } catch (_) {
      // 로컬 캐시 유지
    }
  }

  Future<WorkerRankWageSettings> _loadSettingsForApply({
    bool trySyncRemote = false,
  }) async {
    await _settingsRepo.getSettings();
    if (trySyncRemote) {
      try {
        return await _settingsRepo.syncFromServer();
      } catch (_) {}
    }
    return _settingsRepo.cachedSettings;
  }

  /// 승인 직후·관리자 직접 등록 등 — 연결 인력 일당이 비어 있으면 역할 기본값을 넣는다.
  Future<void> applyDefaultWageForUser(UserRead user) async {
    final rank = user.workerRank.trim();
    if (rank.isEmpty || !kWorkerRankOptions.contains(rank)) return;

    final settings = await _loadSettingsForApply(trySyncRemote: true);
    final wage = settings.wageForRank(rank);
    if (wage == null) return;

    final hid = user.workerHid;
    if (hid == null || hid <= 0) return;

    try {
      final human = await _remote.humanGet(hid);
      final patch = <String, dynamic>{};
      if (human.hdailywage <= 0) patch['hdailywage'] = wage;
      if (human.workerRank.trim().isEmpty) patch['worker_rank'] = rank;
      if (patch.isEmpty) return;
      await _remote.humanPatch(hid, patch);
    } catch (_) {
      // 인력 미생성·네트워크 — 서버 승인 훅에 맡김
    }
  }

  /// 현장 역할이 선택됐는데 일당이 비어 있으면 역할별 기본 일당을 채운다.
  Future<HumanModel> applyRankDefaultWage(HumanModel worker) async {
    final rank = worker.workerRank.trim();
    if (rank.isEmpty) return worker;
    if (worker.hdailyWage > 0) return worker;

    final settings = await _loadSettingsForApply();
    final wage = settings.wageForRank(rank);
    if (wage == null) return worker;

    return HumanModel(
      hid: worker.hid,
      uid: worker.uid,
      hname: worker.hname,
      hnumber: worker.hnumber,
      hmemo: worker.hmemo,
      hdailyWage: wage,
      hdefaultRole: worker.hdefaultRole,
      primarySpecialty: worker.primarySpecialty,
      specialties: worker.specialties,
      career: worker.career,
      workerRank: worker.workerRank,
      canBePlaceMember: worker.canBePlaceMember,
      linkedUserName: worker.linkedUserName,
      hphone: worker.hphone,
      linkedPhone: worker.linkedPhone,
      hstar: worker.hstar,
      hdelete: worker.hdelete,
    );
  }
}
