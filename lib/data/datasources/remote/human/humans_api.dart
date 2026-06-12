import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class HumansRemoteApi {
  HumansRemoteApi(this._http);

  final AppHttpClient _http;

  Future<List<HumanRead>> list() async {
    final r = await _http.get<dynamic>(ApiEndpoint.humans);
    return saMapList(r.data, HumanRead.fromJson);
  }

  Future<HumanRead> get(int hid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.humansHid(hid));
    return HumanRead.fromJson(saParseObject(r.data));
  }

  Future<HumanRead> create(Map<String, dynamic> body) async {
    final r = await _http.post<dynamic>(ApiEndpoint.humans, data: body);
    return HumanRead.fromJson(saParseObject(r.data));
  }

  Future<HumanRead> patch(int hid, Map<String, dynamic> body) async {
    final r =
        await _http.patch<dynamic>(ApiEndpoint.humansHid(hid), data: body);
    return HumanRead.fromJson(saParseObject(r.data));
  }

  Future<void> delete(int hid) async {
    await _http.delete<dynamic>(ApiEndpoint.humansHid(hid));
  }
}
