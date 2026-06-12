import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class WorkCostsRemoteApi {
  WorkCostsRemoteApi(this._http);

  final AppHttpClient _http;

  Future<List<WorkCostRead>> list() async {
    final r = await _http.get<dynamic>(ApiEndpoint.workCosts);
    return saMapList(r.data, WorkCostRead.fromJson);
  }

  Future<WorkCostRead> get(int wid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.workCostsWid(wid));
    return WorkCostRead.fromJson(saParseObject(r.data));
  }

  Future<WorkCostRead> create(Map<String, dynamic> body) async {
    final r = await _http.post<dynamic>(ApiEndpoint.workCosts, data: body);
    return WorkCostRead.fromJson(saParseObject(r.data));
  }

  Future<WorkCostRead> patch(int wid, Map<String, dynamic> body) async {
    final r =
        await _http.patch<dynamic>(ApiEndpoint.workCostsWid(wid), data: body);
    return WorkCostRead.fromJson(saParseObject(r.data));
  }

  Future<void> delete(int wid) async {
    await _http.delete<dynamic>(ApiEndpoint.workCostsWid(wid));
  }
}
