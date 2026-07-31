import 'package:w0001/data/model/place_member_model.dart';

abstract class PlaceMembersRepository {
  Future<List<PlaceMemberRead>> getPlaceMembers(int pid);

  Future<PlaceMemberAddResponse> addMember(
    int pid,
    String workerUid, {
    bool autoAdded = false,
  });

  Future<PlaceMemberRemoveResponse> removeMember(int pid, String workerUid);
}
