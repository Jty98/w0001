import 'package:w0001/data/datasources/remote/place/place_site_guide_api.dart';
import 'package:w0001/data/model/place_site_guide_model.dart';
import 'package:w0001/domain/repository/place_site_guide_repository.dart';

class PlaceSiteGuideRepositoryImpl implements PlaceSiteGuideRepository {
  PlaceSiteGuideRepositoryImpl(this._api);

  final PlaceSiteGuideRemoteApi _api;

  @override
  Future<PlaceSiteGuideModel?> fetch(int pid) => _api.fetch(pid);

  @override
  Future<PlaceSiteGuideModel> save(int pid, PlaceSiteGuideModel model) =>
      _api.save(pid, model);
}
