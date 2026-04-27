import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_remote_api.dart';
import 'package:w0001/data/repository/super_admin_remote_impl.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';
import 'package:w0001/domain/use_case/super_admin_remote_use_case.dart';

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
