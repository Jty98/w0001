import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';

/// `super_admin` CRUD — [SuperAdminRemoteRepository] 를 그대로 노출.
class SuperAdminRemoteUseCase {
  SuperAdminRemoteUseCase(this._repository);

  final SuperAdminRemoteRepository _repository;

  SuperAdminRemoteRepository get repository => _repository;

  // Users
  Future<List<UserRead>> usersList() => _repository.usersList();
  Future<UserRead> userGet(String uid) => _repository.userGet(uid);
  Future<UserRead> userCreate(UserCreateBody body) =>
      _repository.userCreate(body);
  Future<UserRead> userPatch(String uid, Map<String, dynamic> body) =>
      _repository.userPatch(uid, body);
  Future<void> userDelete(String uid) => _repository.userDelete(uid);

  Future<List<UserRead>> usersPendingList({String? q}) =>
      _repository.usersPendingList(q: q);
  Future<List<UserRead>> usersSearch({
    String? role,
    String? approvalStatus,
    bool? isActive,
    String? q,
  }) =>
      _repository.usersSearch(
        role: role,
        approvalStatus: approvalStatus,
        isActive: isActive,
        q: q,
      );
  Future<void> userApprove(String uid, {String? note}) =>
      _repository.userApprove(uid, note: note);
  Future<void> userReject(String uid, {String? note}) =>
      _repository.userReject(uid, note: note);
  Future<void> userSuspend(
    String uid, {
    String? reason,
    required String adminActionToken,
  }) =>
      _repository.userSuspend(
        uid,
        reason: reason,
        adminActionToken: adminActionToken,
      );
  Future<void> userActivate(String uid) => _repository.userActivate(uid);
  Future<UserRead> userChangeRole(
    String uid,
    UserRole role, {
    required String adminActionToken,
  }) =>
      _repository.userChangeRole(uid, role, adminActionToken: adminActionToken);

  // Places
  Future<List<PlaceRead>> placesList() => _repository.placesList();
  Future<PlaceRead> placeGet(int pid) => _repository.placeGet(pid);
  Future<PlaceRead> placeCreate(Map<String, dynamic> body) =>
      _repository.placeCreate(body);
  Future<PlaceRead> placePatch(int pid, Map<String, dynamic> body) =>
      _repository.placePatch(pid, body);
  Future<void> placeDelete(int pid) => _repository.placeDelete(pid);

  // Humans
  Future<List<HumanRead>> humansList() => _repository.humansList();
  Future<HumanRead> humanGet(int hid) => _repository.humanGet(hid);
  Future<HumanRead> humanCreate(Map<String, dynamic> body) =>
      _repository.humanCreate(body);
  Future<HumanRead> humanPatch(int hid, Map<String, dynamic> body) =>
      _repository.humanPatch(hid, body);
  Future<void> humanDelete(int hid) => _repository.humanDelete(hid);

  // Place work days
  Future<List<PlaceWorkDayRead>> placeWorkDaysList() =>
      _repository.placeWorkDaysList();
  Future<PlaceWorkDayRead> placeWorkDayGet(int pwdid) =>
      _repository.placeWorkDayGet(pwdid);
  Future<PlaceWorkDayRead> placeWorkDayCreate(Map<String, dynamic> body) =>
      _repository.placeWorkDayCreate(body);
  Future<PlaceWorkDayRead> placeWorkDayPatch(
    int pwdid,
    Map<String, dynamic> body,
  ) =>
      _repository.placeWorkDayPatch(pwdid, body);
  Future<void> placeWorkDayDelete(int pwdid) =>
      _repository.placeWorkDayDelete(pwdid);

  // Work costs
  Future<List<WorkCostRead>> workCostsList() => _repository.workCostsList();
  Future<WorkCostRead> workCostGet(int wid) => _repository.workCostGet(wid);
  Future<WorkCostRead> workCostCreate(Map<String, dynamic> body) =>
      _repository.workCostCreate(body);
  Future<WorkCostRead> workCostPatch(int wid, Map<String, dynamic> body) =>
      _repository.workCostPatch(wid, body);
  Future<void> workCostDelete(int wid) => _repository.workCostDelete(wid);

  // Material costs
  Future<List<MaterialCostRead>> materialCostsList() =>
      _repository.materialCostsList();
  Future<MaterialCostRead> materialCostGet(int mid) =>
      _repository.materialCostGet(mid);
  Future<MaterialCostRead> materialCostCreate(Map<String, dynamic> body) =>
      _repository.materialCostCreate(body);
  Future<MaterialCostRead> materialCostPatch(
          int mid, Map<String, dynamic> body) =>
      _repository.materialCostPatch(mid, body);
  Future<void> materialCostDelete(int mid) =>
      _repository.materialCostDelete(mid);

  // Place revenues
  Future<List<PlaceRevenueRead>> placeRevenuesList() =>
      _repository.placeRevenuesList();
  Future<PlaceRevenueRead> placeRevenueGet(int rid) =>
      _repository.placeRevenueGet(rid);
  Future<PlaceRevenueRead> placeRevenueCreate(Map<String, dynamic> body) =>
      _repository.placeRevenueCreate(body);
  Future<PlaceRevenueRead> placeRevenuePatch(
          int rid, Map<String, dynamic> body) =>
      _repository.placeRevenuePatch(rid, body);
  Future<void> placeRevenueDelete(int rid) =>
      _repository.placeRevenueDelete(rid);

  // Place collections
  Future<List<PlaceCollectionRead>> placeCollectionsList() =>
      _repository.placeCollectionsList();
  Future<PlaceCollectionRead> placeCollectionGet(int cid) =>
      _repository.placeCollectionGet(cid);
  Future<PlaceCollectionRead> placeCollectionCreate(
          Map<String, dynamic> body) =>
      _repository.placeCollectionCreate(body);
  Future<PlaceCollectionRead> placeCollectionPatch(
    int cid,
    Map<String, dynamic> body,
  ) =>
      _repository.placeCollectionPatch(cid, body);
  Future<void> placeCollectionDelete(int cid) =>
      _repository.placeCollectionDelete(cid);

  // Place worker recents
  Future<List<PlaceWorkerRecentRead>> placeWorkerRecentsList() =>
      _repository.placeWorkerRecentsList();
  Future<PlaceWorkerRecentRead> placeWorkerRecentGet(int pid, int hid) =>
      _repository.placeWorkerRecentGet(pid, hid);
  Future<PlaceWorkerRecentRead> placeWorkerRecentCreate(
    Map<String, dynamic> body,
  ) =>
      _repository.placeWorkerRecentCreate(body);
  Future<PlaceWorkerRecentRead> placeWorkerRecentPatch(
    int pid,
    int hid,
    Map<String, dynamic> body,
  ) =>
      _repository.placeWorkerRecentPatch(pid, hid, body);
  Future<void> placeWorkerRecentDelete(int pid, int hid) =>
      _repository.placeWorkerRecentDelete(pid, hid);

  // Schedule memos
  Future<List<ScheduleMemoRead>> scheduleMemosList() =>
      _repository.scheduleMemosList();
  Future<ScheduleMemoRead> scheduleMemoGet(int sid) =>
      _repository.scheduleMemoGet(sid);
  Future<ScheduleMemoRead> scheduleMemoCreate(Map<String, dynamic> body) =>
      _repository.scheduleMemoCreate(body);
  Future<ScheduleMemoRead> scheduleMemoPatch(
          int sid, Map<String, dynamic> body) =>
      _repository.scheduleMemoPatch(sid, body);
  Future<void> scheduleMemoDelete(int sid) =>
      _repository.scheduleMemoDelete(sid);

  // Place photo groups
  Future<List<PlacePhotoGroupRead>> placePhotoGroupsList() =>
      _repository.placePhotoGroupsList();
  Future<PlacePhotoGroupRead> placePhotoGroupGet(int pgid) =>
      _repository.placePhotoGroupGet(pgid);
  Future<PlacePhotoGroupRead> placePhotoGroupCreate(
          Map<String, dynamic> body) =>
      _repository.placePhotoGroupCreate(body);
  Future<PlacePhotoGroupRead> placePhotoGroupPatch(
    int pgid,
    Map<String, dynamic> body,
  ) =>
      _repository.placePhotoGroupPatch(pgid, body);
  Future<void> placePhotoGroupDelete(int pgid) =>
      _repository.placePhotoGroupDelete(pgid);

  // Place photos
  Future<List<PlacePhotoRead>> placePhotosList() =>
      _repository.placePhotosList();
  Future<PlacePhotoRead> placePhotoGet(int phid) =>
      _repository.placePhotoGet(phid);
  Future<PlacePhotoRead> placePhotoCreate(Map<String, dynamic> body) =>
      _repository.placePhotoCreate(body);
  Future<PlacePhotoRead> placePhotoPatch(int phid, Map<String, dynamic> body) =>
      _repository.placePhotoPatch(phid, body);
  Future<void> placePhotoDelete(int phid) => _repository.placePhotoDelete(phid);

  Future<List<WorkerMgmtNoteRead>> workerMgmtNotesList(int workerHid) =>
      _repository.workerMgmtNotesList(workerHid);
  Future<WorkerMgmtNoteRead> workerMgmtNoteCreate({
    required int workerHid,
    required String noteType,
    required String memo,
    int? rating,
  }) =>
      _repository.workerMgmtNoteCreate(
        workerHid: workerHid,
        noteType: noteType,
        memo: memo,
        rating: rating,
      );
  Future<List<WorkerMgmtConflictRead>> workerMgmtConflictsList({
    bool activeOnly = true,
  }) =>
      _repository.workerMgmtConflictsList(activeOnly: activeOnly);
  Future<WorkerMgmtConflictRead> workerMgmtConflictUpsert({
    required int workerAHid,
    required int workerBHid,
    int severity = 2,
    String note = '',
    bool active = true,
  }) =>
      _repository.workerMgmtConflictUpsert(
        workerAHid: workerAHid,
        workerBHid: workerBHid,
        severity: severity,
        note: note,
        active: active,
      );
  Future<void> workerMgmtConflictDelete(int pairId) =>
      _repository.workerMgmtConflictDelete(pairId);
}
