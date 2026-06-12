import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class PlacePhotosRemoteApi {
  PlacePhotosRemoteApi(this._http);

  final AppHttpClient _http;

  /// [pgid]가 있으면 `GET ...?pgid=` — 해당 묶음의 사진만. 그렇지 않으면 [pid]/[photoType].
  ///
  /// [pgid]가 우선 적용된다(물리 묶음 기준 필터).
  Future<List<PlacePhotoRead>> list({
    int? pid,
    String? photoType,
    int? pgid,
  }) async {
    final qp = <String, dynamic>{};
    if (pgid != null) {
      qp['pgid'] = pgid;
    } else {
      if (pid != null) qp['pid'] = pid;
      if (photoType != null && photoType.isNotEmpty) {
        qp['photo_type'] = photoType;
      }
    }
    final r = await _http.get<dynamic>(
      ApiEndpoint.placePhotos,
      queryParameters: qp.isEmpty ? null : qp,
    );
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
