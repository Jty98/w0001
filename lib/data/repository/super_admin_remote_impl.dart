import 'package:w0001/data/datasources/remote/super_admin/super_admin_remote_api.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';

class SuperAdminRemoteRepositoryImpl implements SuperAdminRemoteRepository {
  SuperAdminRemoteRepositoryImpl(this._api);

  final SuperAdminRemoteApi _api;

  @override
  Future<List<UserRead>> usersList() => _api.usersList();
  @override
  Future<UserRead> userGet(String uid) => _api.userGet(uid);
  @override
  Future<UserRead> userCreate(UserCreateBody body) => _api.userCreate(body);
  @override
  Future<UserRead> userPatch(String uid, Map<String, dynamic> body) =>
      _api.userPatch(uid, body);
  @override
  Future<void> userDelete(String uid) => _api.userDelete(uid);

  @override
  Future<List<UserRead>> usersPendingList({String? q}) =>
      _api.usersPendingList(q: q);

  @override
  Future<List<UserRead>> usersSearch({
    String? role,
    String? approvalStatus,
    bool? isActive,
    String? q,
  }) =>
      _api.usersSearch(
        role: role,
        approvalStatus: approvalStatus,
        isActive: isActive,
        q: q,
      );
  @override
  Future<void> userApprove(String uid, {String? note}) =>
      _api.userApprove(uid, note: note);
  @override
  Future<void> userReject(String uid, {String? note}) =>
      _api.userReject(uid, note: note);
  @override
  Future<void> userSuspend(
    String uid, {
    String? reason,
    required String adminActionToken,
  }) =>
      _api.userSuspend(uid, reason: reason, adminActionToken: adminActionToken);
  @override
  Future<void> userActivate(String uid) => _api.userActivate(uid);
  @override
  Future<UserRead> userChangeRole(
    String uid,
    UserRole role, {
    required String adminActionToken,
  }) =>
      _api.userChangeRole(uid, role, adminActionToken: adminActionToken);

  @override
  Future<List<PlaceRead>> placesList() => _api.placesList();
  @override
  Future<PlaceRead> placeGet(int pid) => _api.placeGet(pid);
  @override
  Future<PlaceRead> placeCreate(Map<String, dynamic> body) =>
      _api.placeCreate(body);
  @override
  Future<PlaceRead> placePatch(int pid, Map<String, dynamic> body) =>
      _api.placePatch(pid, body);
  @override
  Future<void> placeDelete(int pid) => _api.placeDelete(pid);

  @override
  Future<List<HumanRead>> humansList() => _api.humansList();
  @override
  Future<HumanRead> humanGet(int hid) => _api.humanGet(hid);
  @override
  Future<HumanRead> humanCreate(Map<String, dynamic> body) =>
      _api.humanCreate(body);
  @override
  Future<HumanRead> humanPatch(int hid, Map<String, dynamic> body) =>
      _api.humanPatch(hid, body);
  @override
  Future<void> humanDelete(int hid) => _api.humanDelete(hid);

  @override
  Future<List<PlaceWorkDayRead>> placeWorkDaysList() =>
      _api.placeWorkDaysList();
  @override
  Future<PlaceWorkDayRead> placeWorkDayGet(int pwdid) =>
      _api.placeWorkDayGet(pwdid);
  @override
  Future<PlaceWorkDayRead> placeWorkDayCreate(Map<String, dynamic> body) =>
      _api.placeWorkDayCreate(body);
  @override
  Future<PlaceWorkDayRead> placeWorkDayPatch(
    int pwdid,
    Map<String, dynamic> body,
  ) =>
      _api.placeWorkDayPatch(pwdid, body);
  @override
  Future<void> placeWorkDayDelete(int pwdid) => _api.placeWorkDayDelete(pwdid);

  @override
  Future<List<WorkCostRead>> workCostsList() => _api.workCostsList();
  @override
  Future<WorkCostRead> workCostGet(int wid) => _api.workCostGet(wid);
  @override
  Future<WorkCostRead> workCostCreate(Map<String, dynamic> body) =>
      _api.workCostCreate(body);
  @override
  Future<WorkCostRead> workCostPatch(int wid, Map<String, dynamic> body) =>
      _api.workCostPatch(wid, body);
  @override
  Future<void> workCostDelete(int wid) => _api.workCostDelete(wid);

  @override
  Future<List<MaterialCostRead>> materialCostsList() =>
      _api.materialCostsList();
  @override
  Future<MaterialCostRead> materialCostGet(int mid) =>
      _api.materialCostGet(mid);
  @override
  Future<MaterialCostRead> materialCostCreate(Map<String, dynamic> body) =>
      _api.materialCostCreate(body);
  @override
  Future<MaterialCostRead> materialCostPatch(
    int mid,
    Map<String, dynamic> body,
  ) =>
      _api.materialCostPatch(mid, body);
  @override
  Future<void> materialCostDelete(int mid) => _api.materialCostDelete(mid);

  @override
  Future<List<PlaceRevenueRead>> placeRevenuesList() =>
      _api.placeRevenuesList();
  @override
  Future<PlaceRevenueRead> placeRevenueGet(int rid) =>
      _api.placeRevenueGet(rid);
  @override
  Future<PlaceRevenueRead> placeRevenueCreate(Map<String, dynamic> body) =>
      _api.placeRevenueCreate(body);
  @override
  Future<PlaceRevenueRead> placeRevenuePatch(
    int rid,
    Map<String, dynamic> body,
  ) =>
      _api.placeRevenuePatch(rid, body);
  @override
  Future<void> placeRevenueDelete(int rid) => _api.placeRevenueDelete(rid);

  @override
  Future<List<PlaceCollectionRead>> placeCollectionsList() =>
      _api.placeCollectionsList();
  @override
  Future<PlaceCollectionRead> placeCollectionGet(int cid) =>
      _api.placeCollectionGet(cid);
  @override
  Future<PlaceCollectionRead> placeCollectionCreate(
    Map<String, dynamic> body,
  ) =>
      _api.placeCollectionCreate(body);
  @override
  Future<PlaceCollectionRead> placeCollectionPatch(
    int cid,
    Map<String, dynamic> body,
  ) =>
      _api.placeCollectionPatch(cid, body);
  @override
  Future<void> placeCollectionDelete(int cid) =>
      _api.placeCollectionDelete(cid);

  @override
  Future<List<PlaceWorkerRecentRead>> placeWorkerRecentsList() =>
      _api.placeWorkerRecentsList();
  @override
  Future<PlaceWorkerRecentRead> placeWorkerRecentGet(int pid, int hid) =>
      _api.placeWorkerRecentGet(pid, hid);
  @override
  Future<PlaceWorkerRecentRead> placeWorkerRecentCreate(
    Map<String, dynamic> body,
  ) =>
      _api.placeWorkerRecentCreate(body);
  @override
  Future<PlaceWorkerRecentRead> placeWorkerRecentPatch(
    int pid,
    int hid,
    Map<String, dynamic> body,
  ) =>
      _api.placeWorkerRecentPatch(pid, hid, body);
  @override
  Future<void> placeWorkerRecentDelete(int pid, int hid) =>
      _api.placeWorkerRecentDelete(pid, hid);

  @override
  Future<List<ScheduleMemoRead>> scheduleMemosList() =>
      _api.scheduleMemosList();
  @override
  Future<ScheduleMemoRead> scheduleMemoGet(int sid) =>
      _api.scheduleMemoGet(sid);
  @override
  Future<ScheduleMemoRead> scheduleMemoCreate(Map<String, dynamic> body) =>
      _api.scheduleMemoCreate(body);
  @override
  Future<ScheduleMemoRead> scheduleMemoPatch(
    int sid,
    Map<String, dynamic> body,
  ) =>
      _api.scheduleMemoPatch(sid, body);
  @override
  Future<void> scheduleMemoDelete(int sid) => _api.scheduleMemoDelete(sid);

  @override
  Future<List<PlacePhotoGroupRead>> placePhotoGroupsList() =>
      _api.placePhotoGroupsList();
  @override
  Future<PlacePhotoGroupRead> placePhotoGroupGet(int pgid) =>
      _api.placePhotoGroupGet(pgid);
  @override
  Future<PlacePhotoGroupRead> placePhotoGroupCreate(
    Map<String, dynamic> body,
  ) =>
      _api.placePhotoGroupCreate(body);
  @override
  Future<PlacePhotoGroupRead> placePhotoGroupPatch(
    int pgid,
    Map<String, dynamic> body,
  ) =>
      _api.placePhotoGroupPatch(pgid, body);
  @override
  Future<void> placePhotoGroupDelete(int pgid) =>
      _api.placePhotoGroupDelete(pgid);

  @override
  Future<List<PlacePhotoRead>> placePhotosList() => _api.placePhotosList();
  @override
  Future<PlacePhotoRead> placePhotoGet(int phid) => _api.placePhotoGet(phid);
  @override
  Future<PlacePhotoRead> placePhotoCreate(Map<String, dynamic> body) =>
      _api.placePhotoCreate(body);
  @override
  Future<PlacePhotoRead> placePhotoPatch(int phid, Map<String, dynamic> body) =>
      _api.placePhotoPatch(phid, body);
  @override
  Future<void> placePhotoDelete(int phid) => _api.placePhotoDelete(phid);

  @override
  Future<List<WorkerMgmtNoteRead>> workerMgmtNotesList(int workerHid) =>
      _api.workerMgmtNotesList(workerHid);
  @override
  Future<WorkerMgmtNoteRead> workerMgmtNoteCreate({
    required int workerHid,
    required String noteType,
    required String memo,
    int? rating,
  }) =>
      _api.workerMgmtNoteCreate(
        workerHid: workerHid,
        noteType: noteType,
        memo: memo,
        rating: rating,
      );
  @override
  Future<List<WorkerMgmtConflictRead>> workerMgmtConflictsList({
    bool activeOnly = true,
  }) =>
      _api.workerMgmtConflictsList(activeOnly: activeOnly);
  @override
  Future<WorkerMgmtConflictRead> workerMgmtConflictUpsert({
    required int workerAHid,
    required int workerBHid,
    int severity = 2,
    String note = '',
    bool active = true,
  }) =>
      _api.workerMgmtConflictUpsert(
        workerAHid: workerAHid,
        workerBHid: workerBHid,
        severity: severity,
        note: note,
        active: active,
      );
  @override
  Future<void> workerMgmtConflictDelete(int pairId) =>
      _api.workerMgmtConflictDelete(pairId);
}
