import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class PlacesRemoteApi {
  PlacesRemoteApi(this._http);

  final AppHttpClient _http;

  Future<List<PlaceRead>> list() async {
    final r = await _http.get<dynamic>(ApiEndpoint.places);
    return saMapList(r.data, PlaceRead.fromJson);
  }

  Future<PlaceRead> get(int pid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.placesPid(pid));
    return PlaceRead.fromJson(saParseObject(r.data));
  }

  Future<PlaceRead> create(Map<String, dynamic> body) async {
    final r = await _http.post<dynamic>(ApiEndpoint.places, data: body);
    return PlaceRead.fromJson(saParseObject(r.data));
  }

  Future<PlaceRead> patch(int pid, Map<String, dynamic> body) async {
    final r = await _http.patch<dynamic>(ApiEndpoint.placesPid(pid), data: body);
    return PlaceRead.fromJson(saParseObject(r.data));
  }

  Future<void> delete(int pid) async {
    await _http.delete<dynamic>(ApiEndpoint.placesPid(pid));
  }
}
