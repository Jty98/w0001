import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/place_site_guide_model.dart';
import 'package:w0001/util/api_endpoint.dart';

/// `GET` / `PUT` / `PATCH` `/places/{pid}/site-guide`
final class PlaceSiteGuideRemoteApi {
  PlaceSiteGuideRemoteApi(this._http);

  final AppHttpClient _http;

  /// 저장된 인수인계 없음 → `null` (404).
  Future<PlaceSiteGuideModel?> fetch(int pid) async {
    try {
      final r = await _http.get<dynamic>(ApiEndpoint.placesSiteGuide(pid));
      return PlaceSiteGuideModel.fromJson(saParseObject(r.data));
    } on DioException catch (e) {
      final err = e.error;
      if (err is HttpStatusException && err.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<PlaceSiteGuideModel> save(int pid, PlaceSiteGuideModel model) async {
    final r = await _http.put<dynamic>(
      ApiEndpoint.placesSiteGuide(pid),
      data: model.toJsonForPut(),
    );
    return PlaceSiteGuideModel.fromJson(saParseObject(r.data));
  }
}
