import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/place/place_members_api.dart';
import 'package:w0001/data/model/place_member_model.dart';
import 'package:w0001/domain/repository/place_members_repository.dart';

final class PlaceMembersRepositoryImpl implements PlaceMembersRepository {
  PlaceMembersRepositoryImpl(this._api);

  final PlaceMembersApi _api;

  @override
  Future<List<PlaceMemberRead>> getPlaceMembers(int pid) async {
    try {
      return await _api.getPlaceMembers(pid);
    } on HttpStatusException catch (e) {
      if (e.statusCode == 404) return [];
      rethrow;
    }
  }

  @override
  Future<PlaceMemberAddResponse> addMember(int pid, String workerUid) =>
      _api.addMember(pid, workerUid);

  @override
  Future<PlaceMemberRemoveResponse> removeMember(int pid, String workerUid) =>
      _api.removeMember(pid, workerUid);
}
