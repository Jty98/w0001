import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class MaterialCostsRemoteApi {
  MaterialCostsRemoteApi(this._http);

  final AppHttpClient _http;

  Future<List<MaterialCostRead>> list() async {
    final r = await _http.get<dynamic>(ApiEndpoint.materialCosts);
    return saMapList(r.data, MaterialCostRead.fromJson);
  }

  Future<MaterialCostRead> get(int mid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.materialCostsMid(mid));
    return MaterialCostRead.fromJson(saParseObject(r.data));
  }

  Future<MaterialCostRead> create(Map<String, dynamic> body) async {
    final r = await _http.post<dynamic>(ApiEndpoint.materialCosts, data: body);
    return MaterialCostRead.fromJson(saParseObject(r.data));
  }

  Future<MaterialCostRead> patch(int mid, Map<String, dynamic> body) async {
    final r = await _http.patch<dynamic>(
      ApiEndpoint.materialCostsMid(mid),
      data: body,
    );
    return MaterialCostRead.fromJson(saParseObject(r.data));
  }

  Future<void> delete(int mid) async {
    await _http.delete<dynamic>(ApiEndpoint.materialCostsMid(mid));
  }
}
