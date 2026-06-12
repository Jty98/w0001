import 'package:w0001/data/model/place_member_model.dart';
import 'package:w0001/domain/repository/place_members_repository.dart';

class PlaceMembersUseCase {
  PlaceMembersUseCase(this._repository);

  final PlaceMembersRepository _repository;

  Future<List<PlaceMemberRead>> getPlaceMembers(int pid) =>
      _repository.getPlaceMembers(pid);

  Future<PlaceMemberAddResponse> addMember(int pid, String workerUid) =>
      _repository.addMember(pid, workerUid);

  Future<PlaceMemberRemoveResponse> removeMember(int pid, String workerUid) =>
      _repository.removeMember(pid, workerUid);
}
