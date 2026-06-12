import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class PlaceWorkerRecentsRemoteApi {
  PlaceWorkerRecentsRemoteApi(this._http);

  final AppHttpClient _http;

  Future<List<PlaceWorkerRecentRead>> list() async {
    final r = await _http.get<dynamic>(ApiEndpoint.placeWorkerRecents);
    return saMapList(r.data, PlaceWorkerRecentRead.fromJson);
  }

  Future<PlaceWorkerRecentRead> get(int pid, int hid) async {
    final r =
        await _http.get<dynamic>(ApiEndpoint.placeWorkerRecentsPair(pid, hid));
    return PlaceWorkerRecentRead.fromJson(saParseObject(r.data));
  }

  Future<PlaceWorkerRecentRead> create(Map<String, dynamic> body) async {
    final r =
        await _http.post<dynamic>(ApiEndpoint.placeWorkerRecents, data: body);
    return PlaceWorkerRecentRead.fromJson(saParseObject(r.data));
  }

  Future<PlaceWorkerRecentRead> patch(
    int pid,
    int hid,
    Map<String, dynamic> body,
  ) async {
    final r = await _http.patch<dynamic>(
      ApiEndpoint.placeWorkerRecentsPair(pid, hid),
      data: body,
    );
    return PlaceWorkerRecentRead.fromJson(saParseObject(r.data));
  }

  Future<void> delete(int pid, int hid) async {
    await _http.delete<dynamic>(ApiEndpoint.placeWorkerRecentsPair(pid, hid));
  }
}
