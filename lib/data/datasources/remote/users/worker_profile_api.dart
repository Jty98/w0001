import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/util/api_endpoint.dart';

final class WorkerProfileRemoteApi {
  WorkerProfileRemoteApi(this._http);

  final AppHttpClient _http;

  Future<WorkerProfileRead> get() async {
    final r = await _http.get<dynamic>(ApiEndpoint.usersMeWorkerProfile);
    return WorkerProfileRead.fromJson(saParseObject(r.data));
  }

  Future<WorkerProfileRead> put(WorkerProfileRead body) async {
    final r = await _http.put<dynamic>(
      ApiEndpoint.usersMeWorkerProfile,
      data: body.toJson(),
    );
    return WorkerProfileRead.fromJson(saParseObject(r.data));
  }
}
