import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/local/worker_rank_wage_settings_storage.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/worker_management/worker_management_api.dart';
import 'package:w0001/data/model/worker_rank_wage_settings.dart';
import 'package:w0001/data/model/work_unit_preset.dart';
import 'package:w0001/data/repository/worker_rank_wage_settings_repository_impl.dart';
import 'package:w0001/domain/repository/worker_rank_wage_settings_repository.dart';
import 'package:w0001/domain/use_case/worker_rank_wage_settings_use_case.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';

final workerRankWageSettingsRepositoryProvider =
    Provider<WorkerRankWageSettingsRepository>((ref) {
  return WorkerRankWageSettingsRepositoryImpl(
    WorkerManagementRemoteApi(AppHttpClient.I),
    WorkerRankWageSettingsStorage(),
  );
});

final workerRankWageSettingsUseCaseProvider =
    Provider<WorkerRankWageSettingsUseCase>((ref) {
  return WorkerRankWageSettingsUseCase(
    ref.read(workerRankWageSettingsRepositoryProvider),
    ref.read(superAdminRemoteRepositoryProvider),
  );
});

final workerRankWageSettingsProvider = AsyncNotifierProvider<
    WorkerRankWageSettingsNotifier,
    WorkerRankWageSettings>(WorkerRankWageSettingsNotifier.new);

class WorkerRankWageSettingsNotifier
    extends AsyncNotifier<WorkerRankWageSettings> {
  WorkerRankWageSettingsUseCase get _uc =>
      ref.read(workerRankWageSettingsUseCaseProvider);

  @override
  Future<WorkerRankWageSettings> build() async {
    final local = await _uc.getSettings();
    unawaited(_syncFromServerQuietly());
    return local;
  }

  Future<void> _syncFromServerQuietly() async {
    try {
      final remote = await _uc.syncFromServer();
      if (ref.mounted) state = AsyncData(remote);
    } catch (_) {
      // 로컬 유지
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        return await _uc.syncFromServer();
      } catch (_) {
        return _uc.getSettings();
      }
    });
  }

  Future<bool> save({
    required List<String> rankOrder,
    required Map<String, int> wagesByRank,
    List<WorkUnitPreset>? workUnits,
    String? defaultWorkUnitId,
  }) async {
    final previous = state.value ?? WorkerRankWageSettings.empty();
    var next = previous.withOrderedRanks(rankOrder, wagesByRank);
    if (workUnits != null) {
      next = next.withWorkUnits(
        workUnits,
        defaultWorkUnitId: defaultWorkUnitId,
      );
    } else if (defaultWorkUnitId != null) {
      next = next.copyWith(defaultWorkUnitId: defaultWorkUnitId);
    }
    next = next.copyWith(
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    state = AsyncData(next);

    try {
      final saved = await _uc.saveSettings(next);
      state = AsyncData(saved);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}
