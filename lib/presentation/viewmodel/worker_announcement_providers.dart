import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/worker_announcements_remote_api.dart';
import 'package:w0001/data/repository/worker_announcement_repository_impl.dart';
import 'package:w0001/domain/repository/worker_announcement_repository.dart';
import 'package:w0001/domain/use_case/worker_announcement_use_case.dart';

final workerAnnouncementsRemoteApiProvider =
    Provider<WorkerAnnouncementsRemoteApi>(
  (ref) => WorkerAnnouncementsRemoteApi(AppHttpClient.I),
);

final workerAnnouncementRepositoryProvider =
    Provider<WorkerAnnouncementRepository>(
  (ref) => WorkerAnnouncementRepositoryImpl(
    ref.read(workerAnnouncementsRemoteApiProvider),
  ),
);

final workerAnnouncementUseCaseProvider = Provider<WorkerAnnouncementUseCase>(
  (ref) => WorkerAnnouncementUseCase(
    ref.read(workerAnnouncementRepositoryProvider),
  ),
);
