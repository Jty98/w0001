import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class PlaceCollectionsRemoteApi {
  PlaceCollectionsRemoteApi(this._http);

  final AppHttpClient _http;

  Future<List<PlaceCollectionRead>> list() async {
    final r = await _http.get<dynamic>(ApiEndpoint.placeCollections);
    return saMapList(r.data, PlaceCollectionRead.fromJson);
  }

  Future<PlaceCollectionRead> get(int cid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.placeCollectionsCid(cid));
    return PlaceCollectionRead.fromJson(saParseObject(r.data));
  }

  Future<PlaceCollectionRead> create(Map<String, dynamic> body) async {
    final r =
        await _http.post<dynamic>(ApiEndpoint.placeCollections, data: body);
    return PlaceCollectionRead.fromJson(saParseObject(r.data));
  }

  Future<PlaceCollectionRead> patch(int cid, Map<String, dynamic> body) async {
    final r = await _http.patch<dynamic>(
      ApiEndpoint.placeCollectionsCid(cid),
      data: body,
    );
    return PlaceCollectionRead.fromJson(saParseObject(r.data));
  }

  Future<void> delete(int cid) async {
    await _http.delete<dynamic>(ApiEndpoint.placeCollectionsCid(cid));
  }
}
