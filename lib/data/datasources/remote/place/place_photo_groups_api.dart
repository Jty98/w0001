import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class PlacePhotoGroupsRemoteApi {
  PlacePhotoGroupsRemoteApi(this._http);

  final AppHttpClient _http;

  /// [pid]가 있으면 `GET ...?pid=` — 해당 현장 묶음만. 없으면 권한 범위 내 전체.
  Future<List<PlacePhotoGroupRead>> list({int? pid}) async {
    final qp = <String, dynamic>{};
    if (pid != null) qp['pid'] = pid;
    final r = await _http.get<dynamic>(
      ApiEndpoint.placePhotoGroups,
      queryParameters: qp.isEmpty ? null : qp,
    );
    return saMapList(r.data, PlacePhotoGroupRead.fromJson);
  }

  Future<PlacePhotoGroupRead> get(int pgid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.placePhotoGroupsPgid(pgid));
    return PlacePhotoGroupRead.fromJson(saParseObject(r.data));
  }

  Future<PlacePhotoGroupRead> create(Map<String, dynamic> body) async {
    final r =
        await _http.post<dynamic>(ApiEndpoint.placePhotoGroups, data: body);
    return PlacePhotoGroupRead.fromJson(saParseObject(r.data));
  }

  Future<PlacePhotoGroupRead> patch(
    int pgid,
    Map<String, dynamic> body,
  ) async {
    final r = await _http.patch<dynamic>(
      ApiEndpoint.placePhotoGroupsPgid(pgid),
      data: body,
    );
    return PlacePhotoGroupRead.fromJson(saParseObject(r.data));
  }

  Future<void> delete(int pgid) async {
    await _http.delete<dynamic>(ApiEndpoint.placePhotoGroupsPgid(pgid));
  }
}
