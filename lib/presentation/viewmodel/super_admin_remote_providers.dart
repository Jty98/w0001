import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_remote_api.dart';
import 'package:w0001/data/repository/super_admin_remote_impl.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';
import 'package:w0001/domain/use_case/super_admin_remote_use_case.dart';
import 'package:w0001/util/human_work_assignability.dart';

final superAdminRemoteApiProvider = Provider<SuperAdminRemoteApi>(
  (ref) => SuperAdminRemoteApi(AppHttpClient.I),
);

final superAdminRemoteRepositoryProvider = Provider<SuperAdminRemoteRepository>(
  (ref) => SuperAdminRemoteRepositoryImpl(
    ref.read(superAdminRemoteApiProvider),
  ),
);

final superAdminRemoteUseCaseProvider = Provider<SuperAdminRemoteUseCase>(
  (ref) => SuperAdminRemoteUseCase(
    ref.read(superAdminRemoteRepositoryProvider),
  ),
);

/// 활동 정지·미승인 등 작업 투입 불가 회원 uid (humans 응답에 상태 없을 때 폴백).
final nonAssignableMemberUidsProvider = FutureProvider<Set<String>>((ref) {
  return fetchNonAssignableMemberUids(
    ref.watch(superAdminRemoteUseCaseProvider),
  );
});
