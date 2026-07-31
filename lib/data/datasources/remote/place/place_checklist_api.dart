import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/place_checklist_models.dart';
import 'package:w0001/util/api_endpoint.dart';

final class PlaceChecklistRemoteApi {
  PlaceChecklistRemoteApi(this._http);

  final AppHttpClient _http;

  Future<PlaceChecklistSnapshot> fetch({
    required int pid,
    required String from,
    required String to,
  }) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.placesChecklist(pid),
      queryParameters: <String, dynamic>{
        'from': from,
        'to': to,
      },
    );
    return _parseSnapshot(pid, saParseObject(r.data));
  }

  Future<PlaceChecklistItem> createItem({
    required int pid,
    required PlaceChecklistItem item,
  }) async {
    final r = await _http.post<dynamic>(
      ApiEndpoint.placesChecklistItems(pid),
      data: _createBody(item),
    );
    return PlaceChecklistItem.fromJson(saParseObject(r.data));
  }

  Future<PlaceChecklistItem> patchItem({
    required int pid,
    required PlaceChecklistItem item,
  }) async {
    final r = await _http.patch<dynamic>(
      ApiEndpoint.placesChecklistItem(pid, item.id),
      data: _patchBody(item),
    );
    return PlaceChecklistItem.fromJson(saParseObject(r.data));
  }

  Future<void> deleteItem({
    required int pid,
    required String itemId,
  }) async {
    await _http.delete<dynamic>(
      ApiEndpoint.placesChecklistItem(pid, itemId),
    );
  }

  Future<PlaceChecklistDeferral> deferItem({
    required int pid,
    required String itemId,
    required String toDate,
    String reason = '',
  }) async {
    final r = await _http.post<dynamic>(
      ApiEndpoint.placesChecklistItemDefer(pid, itemId),
      data: <String, dynamic>{
        'to_date': toDate,
        'reason': reason.trim(),
      },
    );
    final body = saParseObject(r.data);
    final raw = body['deferral'];
    if (raw is Map) {
      return PlaceChecklistDeferral.fromJson(
        Map<String, dynamic>.from(raw),
      );
    }
    return PlaceChecklistDeferral.fromJson(body);
  }

  static Map<String, dynamic> _createBody(PlaceChecklistItem item) {
    return <String, dynamic>{
      'work_date': item.workDate,
      'title': item.title.trim(),
      'process_group': item.processGroup.trim(),
      'sort_order': item.sortOrder,
    };
  }

  static Map<String, dynamic> _patchBody(PlaceChecklistItem item) {
    return <String, dynamic>{
      'title': item.title.trim(),
      'process_group': item.processGroup.trim(),
      'status': item.status.toJson(),
      'sort_order': item.sortOrder,
    };
  }

  static PlaceChecklistSnapshot _parseSnapshot(
    int pid,
    Map<String, dynamic> body,
  ) {
    final items = <PlaceChecklistItem>[];
    final rawItems = body['items'];
    if (rawItems is List) {
      for (final e in rawItems) {
        if (e is Map) {
          items.add(
            PlaceChecklistItem.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    final deferrals = <PlaceChecklistDeferral>[];
    final rawDef = body['deferrals'];
    if (rawDef is List) {
      for (final e in rawDef) {
        if (e is Map) {
          deferrals.add(
            PlaceChecklistDeferral.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return PlaceChecklistSnapshot(
      placeId: pid,
      items: items,
      deferrals: deferrals,
    );
  }
}
