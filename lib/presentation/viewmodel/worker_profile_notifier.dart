import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/users/worker_profile_api.dart';
import 'package:w0001/data/model/worker_profile_model.dart';

final workerProfileApiProvider = Provider<WorkerProfileRemoteApi>(
  (ref) => WorkerProfileRemoteApi(AppHttpClient.I),
);

class WorkerProfileNotifier extends AsyncNotifier<WorkerProfileRead?> {
  @override
  Future<WorkerProfileRead?> build() async {
    try {
      return await ref.read(workerProfileApiProvider).get();
    } catch (_) {
      return const WorkerProfileRead();
    }
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(() async {
      try {
        return await ref.read(workerProfileApiProvider).get();
      } catch (_) {
        return const WorkerProfileRead();
      }
    });
  }

  Future<void> save(WorkerProfileRead profile) async {
    final previous = state;
    try {
      final saved = await ref.read(workerProfileApiProvider).put(profile);
      state = AsyncData(saved);
    } catch (e, st) {
      state = previous;
      Error.throwWithStackTrace(e, st);
    }
  }
}

final workerProfileProvider =
    AsyncNotifierProvider<WorkerProfileNotifier, WorkerProfileRead?>(
  WorkerProfileNotifier.new,
);
