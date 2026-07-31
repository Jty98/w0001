import 'package:w0001/data/model/place_checklist_models.dart';

abstract class PlaceChecklistRepository {
  Future<PlaceChecklistSnapshot> fetchForPlace(
    int placeId, {
    required String from,
    required String to,
  });

  Future<PlaceChecklistItem> upsertItem({
    required int placeId,
    required PlaceChecklistItem item,
  });

  Future<void> deleteItem({
    required int placeId,
    required String itemId,
  });

  /// 다음날로 미루기 — 원본 `deferred`, 대상일에 새 항목 생성, 기록 추가.
  Future<PlaceChecklistDeferral> deferItem({
    required int placeId,
    required String itemId,
    required String toDate,
    String reason = '',
  });
}
