import 'package:w0001/data/model/human_private_models.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_remote_api.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/place_work_day_instruction_layers.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/work_cost_period_totals.dart';
import 'package:w0001/data/model/work_cost_worker_summary.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/domain/repository/super_admin_remote_abst.dart';

class SuperAdminRemoteRepositoryImpl implements SuperAdminRemoteRepository {
  SuperAdminRemoteRepositoryImpl(this._api);

  final SuperAdminRemoteApi _api;

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
  Future<PagedResult<UserRead>> usersPendingPage({
    String? q,
    int limit = kListPageSize,
    String? cursor,
  }) =>
      _api.usersPendingPage(q: q, limit: limit, cursor: cursor);

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
  Future<PagedResult<UserRead>> usersSearchPage({
    String? role,
    String? approvalStatus,
    bool? isActive,
    String? q,
    int limit = kListPageSize,
    String? cursor,
  }) =>
      _api.usersSearchPage(
        role: role,
        approvalStatus: approvalStatus,
        isActive: isActive,
        q: q,
        limit: limit,
        cursor: cursor,
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
  Future<void> placeDelete(int pid, {bool permanent = false}) =>
      _api.placeDelete(pid, permanent: permanent);

  @override
  Future<List<HumanRead>> humansList() => _api.humansList();
  @override
  Future<List<HumanRead>> humansQuery(ListQuery query) =>
      _api.humansQuery(query);
  @override
  Future<PagedResult<HumanRead>> humansQueryPage(ListQuery query) =>
      _api.humansQueryPage(query);
  @override
  Future<HumanRead> humanGet(int hid) => _api.humanGet(hid);
  @override
  Future<List<HumanRead>> humanGetBatch(List<int> hids) =>
      _api.humans.getBatch(hids);
  @override
  Future<HumanPrivateRead> humanGetPrivate(int hid) =>
      _api.humanGetPrivate(hid);
  @override
  Future<HumanPrivateRead> humanPatchPrivate(
          int hid, Map<String, dynamic> body) =>
      _api.humanPatchPrivate(hid, body);
  @override
  Future<HumanRead> humanCreate(Map<String, dynamic> body) =>
      _api.humanCreate(body);
  @override
  Future<HumanRead> humanPatch(int hid, Map<String, dynamic> body) =>
      _api.humanPatch(hid, body);
  @override
  Future<void> humanDelete(int hid) => _api.humanDelete(hid);
  @override
  Future<String> humanRevealRrn({required int hid, required String reason}) =>
      _api.humanRevealRrn(hid: hid, reason: reason);
  @override
  Future<String> humanRevealHphone(
          {required int hid, required String reason}) =>
      _api.humanRevealHphone(hid: hid, reason: reason);
  @override
  Future<String> humanRevealLinkedPhone(
          {required int hid, required String reason}) =>
      _api.humanRevealLinkedPhone(hid: hid, reason: reason);
  @override
  Future<String> humanRevealBankAccount(
          {required int hid, required String reason}) =>
      _api.humanRevealBankAccount(hid: hid, reason: reason);

  @override
  Future<List<HumanRead>> humanGetPlaceRecentWorkers({
    required int pid,
    int limit = 100,
    int offset = 0,
  }) =>
      _api.humanGetPlaceRecentWorkers(pid: pid, limit: limit, offset: offset);

  @override
  Future<List<PlaceWorkDayRead>> placeWorkDaysList() =>
      _api.placeWorkDaysList();
  @override
  Future<List<PlaceWorkDayRead>> placeWorkDaysQuery(ListQuery query) =>
      _api.placeWorkDaysQuery(query);
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
  Future<PlaceWorkDayInstructionBundle> placeWorkDayInstructionBundle({
    required int pid,
    required String workdate,
  }) =>
      _api.placeWorkDayInstructionBundle(pid: pid, workdate: workdate);

  @override
  Future<void> placeWorkDaySiteInstructionUpsert({
    required int pid,
    required String workdate,
    required List<WorkerAnnouncementBlock> blocks,
  }) =>
      _api.placeWorkDaySiteInstructionUpsert(
        pid: pid,
        workdate: workdate,
        blocks: blocks,
      );

  @override
  Future<void> placeWorkDayProcessInstructionUpsert({
    required int pid,
    required String workdate,
    required String workrole,
    required List<WorkerAnnouncementBlock> blocks,
  }) =>
      _api.placeWorkDayProcessInstructionUpsert(
        pid: pid,
        workdate: workdate,
        workrole: workrole,
        blocks: blocks,
      );

  @override
  Future<List<WorkCostRead>> workCostsList() => _api.workCostsList();
  @override
  Future<List<WorkCostRead>> workCostsQuery(ListQuery query) =>
      _api.workCostsQuery(query);
  @override
  Future<WorkCostPeriodTotals?> workCostsPeriodTotals(ListQuery query) =>
      _api.workCostsPeriodTotals(query);
  @override
  Future<PagedResult<WorkCostWorkerSummary>?> workCostsWorkerSummariesPage(
    ListQuery query,
  ) =>
      _api.workCostsWorkerSummariesPage(query);
  @override
  Future<WorkCostRead> workCostGet(int wid) => _api.workCostGet(wid);
  @override
  Future<WorkCostRead> workCostCreate(Map<String, dynamic> body) =>
      _api.workCostCreate(body);
  @override
  Future<WorkCostRead> workCostPatch(int wid, Map<String, dynamic> body) =>
      _api.workCostPatch(wid, body);
  @override
  Future<void> workCostCompletePatch(int wid, int wcomplete) =>
      _api.workCostCompletePatch(wid, wcomplete);
  @override
  Future<void> workCostDelete(int wid) => _api.workCostDelete(wid);

  @override
  Future<List<MaterialCostRead>> materialCostsList() =>
      _api.materialCostsList();
  @override
  Future<List<MaterialCostRead>> materialCostsQuery(ListQuery query) =>
      _api.materialCostsQuery(query);
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
  Future<List<PlaceRevenueRead>> placeRevenuesQuery(ListQuery query) =>
      _api.placeRevenuesQuery(query);
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
  Future<List<ScheduleMemoRead>> scheduleMemosQuery(ListQuery query) =>
      _api.scheduleMemosQuery(query);

  @override
  Future<PagedResult<ScheduleMemoRead>> scheduleMemosQueryPage(
    ListQuery query,
  ) =>
      _api.scheduleMemosQueryPage(query);
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
  Future<PagedResult<WorkerMgmtNoteRead>> workerMgmtNotesPage(
    int workerHid, {
    int limit = kListPageSize,
    String? cursor,
  }) =>
      _api.workerMgmtNotesPage(workerHid, limit: limit, cursor: cursor);
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
  Future<PagedResult<WorkerMgmtConflictRead>> workerMgmtConflictsPage({
    bool activeOnly = true,
    int limit = kListPageSize,
    String? cursor,
  }) =>
      _api.workerMgmtConflictsPage(
        activeOnly: activeOnly,
        limit: limit,
        cursor: cursor,
      );
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

  @override
  Future<Map<String, dynamic>> placeBulkAssignWorkforce({
    required int pid,
    required Map<String, dynamic> body,
  }) =>
      _api.placesBulkAssignWorkforce(pid: pid, body: body);
}
