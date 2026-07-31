import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class PlacePhotoGroupsRemoteApi {
  PlacePhotoGroupsRemoteApi(this._http);

  final AppHttpClient _http;

  Future<PagedResult<PlacePhotoGroupRead>> listPage(ListQuery query) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.placePhotoGroups,
      queryParameters: query.toQueryParameters(),
    );
    return saParsePagedList(r.data, PlacePhotoGroupRead.fromJson);
  }

  /// [pid]가 있으면 `GET ...?pid=` — 해당 현장 묶음만.
  Future<List<PlacePhotoGroupRead>> list({int? pid}) async {
    final q = pid == null ? const ListQuery() : ListQuery(pid: pid);
    final page = await listPage(q);
    return page.items;
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
