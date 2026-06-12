import 'package:w0001/data/model/place_site_guide_model.dart';

abstract class PlaceSiteGuideRepository {
  /// 없으면 `null` (404).
  Future<PlaceSiteGuideModel?> fetch(int pid);

  Future<PlaceSiteGuideModel> save(int pid, PlaceSiteGuideModel model);
}
