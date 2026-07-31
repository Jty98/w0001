import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/place_member_model.dart';
import 'package:w0001/domain/repository/place_members_repository.dart';

class PlaceMembersUseCase {
  PlaceMembersUseCase(this._repository);

  final PlaceMembersRepository _repository;

  Future<List<PlaceMemberRead>> getPlaceMembers(int pid) =>
      _repository.getPlaceMembers(pid);

  Future<PlaceMemberAddResponse> addMember(
    int pid,
    String workerUid, {
    bool autoAdded = false,
  }) =>
      _repository.addMember(pid, workerUid, autoAdded: autoAdded);

  Future<PlaceMemberRemoveResponse> removeMember(int pid, String workerUid) =>
      _repository.removeMember(pid, workerUid);

  /// 작업 투입된 앱 회원에게 현장 멤버 권한 부여 (이미 멤버면 무시).
  ///
  /// 작업 투입 흐름에서는 [autoAdded] 로 초대 알림이 중복되지 않도록 요청한다.
  Future<void> inviteAssignedWorkersToPlace(
    int pid,
    Iterable<HumanModel> humans,
  ) async {
    final existing = await getPlaceMembers(pid);
    final memberUids =
        existing.map((m) => m.uid.trim()).where((u) => u.isNotEmpty).toSet();

    final seen = <String>{};
    for (final h in humans) {
      final uid = h.uid?.trim();
      if (uid == null || uid.isEmpty || !seen.add(uid)) continue;
      if (memberUids.contains(uid)) continue;
      try {
        await addMember(pid, uid, autoAdded: true);
        memberUids.add(uid);
      } catch (_) {
        // 이미 멤버이거나 초대 불가 — 투입 자체는 유지
      }
    }
  }
}
