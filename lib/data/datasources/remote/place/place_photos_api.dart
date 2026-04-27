import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class PlacePhotosRemoteApi {
  PlacePhotosRemoteApi(this._http);

  final AppHttpClient _http;

  Future<List<PlacePhotoRead>> list() async {
    final r = await _http.get<dynamic>(ApiEndpoint.placePhotos);
    return saMapList(r.data, PlacePhotoRead.fromJson);
  }

  Future<PlacePhotoRead> get(int phid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.placePhotosPhid(phid));
    return PlacePhotoRead.fromJson(saParseObject(r.data));
  }

  Future<PlacePhotoRead> create(Map<String, dynamic> body) async {
    final r = await _http.post<dynamic>(ApiEndpoint.placePhotos, data: body);
    return PlacePhotoRead.fromJson(saParseObject(r.data));
  }

  Future<PlacePhotoRead> patch(int phid, Map<String, dynamic> body) async {
    final r = await _http.patch<dynamic>(
      ApiEndpoint.placePhotosPhid(phid),
      data: body,
    );
    return PlacePhotoRead.fromJson(saParseObject(r.data));
  }

  Future<void> delete(int phid) async {
    await _http.delete<dynamic>(ApiEndpoint.placePhotosPhid(phid));
  }
}
