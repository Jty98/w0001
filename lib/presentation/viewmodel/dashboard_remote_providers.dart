import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/dashboard/dashboard_api.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/repository/dashboard_remote_impl.dart';
import 'package:w0001/domain/repository/dashboard_remote_abst.dart';
import 'package:w0001/domain/use_case/dashboard_remote_use_case.dart';

final dashboardRemoteApiProvider = Provider<DashboardRemoteApi>(
  (ref) => DashboardRemoteApi(AppHttpClient.I),
);

final dashboardRemoteRepositoryProvider = Provider<DashboardRemoteRepository>(
  (ref) => DashboardRemoteRepositoryImpl(
    ref.read(dashboardRemoteApiProvider),
  ),
);

final dashboardRemoteUseCaseProvider = Provider<DashboardRemoteUseCase>(
  (ref) => DashboardRemoteUseCase(
    ref.read(dashboardRemoteRepositoryProvider),
  ),
);
