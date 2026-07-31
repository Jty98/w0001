import 'package:w0001/data/datasources/remote/place/place_checklist_api.dart';
import 'package:w0001/data/model/place_checklist_models.dart';
import 'package:w0001/domain/repository/place_checklist_repository.dart';

class PlaceChecklistRemoteRepository implements PlaceChecklistRepository {
  PlaceChecklistRemoteRepository(this._api);

  final PlaceChecklistRemoteApi _api;

  @override
  Future<PlaceChecklistSnapshot> fetchForPlace(
    int placeId, {
    required String from,
    required String to,
  }) {
    if (placeId <= 0) {
      return Future.value(
        PlaceChecklistSnapshot(
          placeId: placeId,
          items: const [],
          deferrals: const [],
        ),
      );
    }
    return _api.fetch(pid: placeId, from: from, to: to);
  }

  @override
  Future<PlaceChecklistItem> upsertItem({
    required int placeId,
    required PlaceChecklistItem item,
  }) async {
    final trimmedTitle = item.title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('체크리스트 제목이 비어 있습니다.');
    }
    final normalized = item.copyWith(
      title: trimmedTitle,
      processGroup: item.processGroup.trim(),
    );
    if (normalized.id.isEmpty) {
      return _api.createItem(pid: placeId, item: normalized);
    }
    return _api.patchItem(pid: placeId, item: normalized);
  }

  @override
  Future<void> deleteItem({
    required int placeId,
    required String itemId,
  }) {
    if (itemId.isEmpty) return Future<void>.value();
    return _api.deleteItem(pid: placeId, itemId: itemId);
  }

  @override
  Future<PlaceChecklistDeferral> deferItem({
    required int placeId,
    required String itemId,
    required String toDate,
    String reason = '',
  }) {
    return _api.deferItem(
      pid: placeId,
      itemId: itemId,
      toDate: toDate,
      reason: reason,
    );
  }
}
