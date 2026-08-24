import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/auth/users_api.dart';
import 'package:w0001/data/datasources/remote/cost/material_costs_api.dart';
import 'package:w0001/data/datasources/remote/cost/work_costs_api.dart';
import 'package:w0001/data/datasources/remote/human/humans_api.dart';
import 'package:w0001/data/datasources/remote/place/place_photo_groups_api.dart';
import 'package:w0001/data/datasources/remote/place/place_photos_api.dart';
import 'package:w0001/data/datasources/remote/place/place_revenues_api.dart';
import 'package:w0001/data/datasources/remote/place/place_work_days_api.dart';
import 'package:w0001/data/datasources/remote/place/place_work_day_instructions_api.dart';
import 'package:w0001/data/datasources/remote/place/place_worker_recents_api.dart';
import 'package:w0001/data/datasources/remote/place/places_api.dart';
import 'package:w0001/data/datasources/remote/schedule_memo/schedule_memos_api.dart';
import 'package:w0001/data/datasources/remote/worker_management/worker_management_api.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/human_private_models.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/place_work_day_instruction_layers.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/work_cost_period_totals.dart';
import 'package:w0001/data/model/work_cost_worker_summary.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';

/// `require_super_admin` CRUD. 기능별 [UsersRemoteApi] 등에 위임한다.
final class SuperAdminRemoteApi {
  SuperAdminRemoteApi(AppHttpClient http)
      : users = UsersRemoteApi(http),
        places = PlacesRemoteApi(http),
        humans = HumansRemoteApi(http),
        placeWorkDays = PlaceWorkDaysRemoteApi(http),
        placeWorkDayInstructions = PlaceWorkDayInstructionsRemoteApi(http),
        workCosts = WorkCostsRemoteApi(http),
        materialCosts = MaterialCostsRemoteApi(http),
        placeRevenues = PlaceRevenuesRemoteApi(http),
        placeWorkerRecents = PlaceWorkerRecentsRemoteApi(http),
        scheduleMemos = ScheduleMemosRemoteApi(http),
        placePhotoGroups = PlacePhotoGroupsRemoteApi(http),
        placePhotos = PlacePhotosRemoteApi(http),
        workerManagement = WorkerManagementRemoteApi(http);

  final UsersRemoteApi users;
  final PlacesRemoteApi places;
  final HumansRemoteApi humans;
  final PlaceWorkDaysRemoteApi placeWorkDays;
  final PlaceWorkDayInstructionsRemoteApi placeWorkDayInstructions;
  final WorkCostsRemoteApi workCosts;
  final MaterialCostsRemoteApi materialCosts;
  final PlaceRevenuesRemoteApi placeRevenues;
  final PlaceWorkerRecentsRemoteApi placeWorkerRecents;
  final ScheduleMemosRemoteApi scheduleMemos;
  final PlacePhotoGroupsRemoteApi placePhotoGroups;
  final PlacePhotosRemoteApi placePhotos;
  final WorkerManagementRemoteApi workerManagement;

  // --- 퍼블릭 API (Repository 와 동일 시그니처) ---

  Future<UserRead> userGet(String uid) => users.get(uid);
  Future<UserRead> userCreate(UserCreateBody body) => users.create(body);
  Future<UserRead> userPatch(String uid, Map<String, dynamic> body) =>
      users.patch(uid, body);
  Future<void> userDelete(String uid) => users.delete(uid);

  Future<List<UserRead>> usersPendingList({String? q}) =>
      users.pendingPage(q: q).then((p) => p.items);
  Future<PagedResult<UserRead>> usersPendingPage({
    String? q,
    int limit = kListPageSize,
    String? cursor,
  }) =>
      users.pendingPage(q: q, limit: limit, cursor: cursor);

  Future<List<UserRead>> usersSearch({
    String? role,
    String? approvalStatus,
    bool? isActive,
    String? q,
  }) =>
      usersSearchPage(
        role: role,
        approvalStatus: approvalStatus,
        isActive: isActive,
        q: q,
      ).then((p) => p.items);

  Future<PagedResult<UserRead>> usersSearchPage({
    String? role,
    String? approvalStatus,
    bool? isActive,
    String? q,
    int limit = kListPageSize,
    String? cursor,
  }) =>
      users.searchPage(
        role: role,
        approvalStatus: approvalStatus,
        isActive: isActive,
        q: q,
        limit: limit,
        cursor: cursor,
      );

  Future<void> userApprove(String uid, {String? note}) =>
      users.approve(uid, note: note);
  Future<void> userReject(String uid, {String? note}) =>
      users.reject(uid, note: note);
  Future<void> userSuspend(
    String uid, {
    String? reason,
    required String adminActionToken,
  }) =>
      users.suspend(uid, reason: reason, adminActionToken: adminActionToken);
  Future<void> userActivate(String uid) => users.activate(uid);
  Future<UserRead> userChangeRole(
    String uid,
    UserRole role, {
    required String adminActionToken,
  }) =>
      users.changeRole(uid, role, adminActionToken: adminActionToken);

  Future<List<PlaceRead>> placesList() => places.list();
  Future<PlaceRead> placeGet(int pid) => places.get(pid);
  Future<PlaceRead> placeCreate(Map<String, dynamic> body) =>
      places.create(body);
  Future<PlaceRead> placePatch(int pid, Map<String, dynamic> body) =>
      places.patch(pid, body);
  Future<void> placeDelete(int pid, {bool permanent = false}) =>
      places.delete(pid, permanent: permanent);

  Future<List<HumanRead>> humansList() => humans.list();
  Future<List<HumanRead>> humansQuery(ListQuery query) => humans.listAll(query);
  Future<PagedResult<HumanRead>> humansQueryPage(ListQuery query) =>
      humans.listPage(query);
  Future<HumanRead> humanGet(int hid) => humans.get(hid);
  Future<HumanPrivateRead> humanGetPrivate(int hid) => humans.getPrivate(hid);
  Future<HumanPrivateRead> humanPatchPrivate(
          int hid, Map<String, dynamic> body) =>
      humans.patchPrivate(hid, body);
  Future<HumanRead> humanCreate(Map<String, dynamic> body) =>
      humans.create(body);
  Future<HumanRead> humanPatch(int hid, Map<String, dynamic> body) =>
      humans.patch(hid, body);
  Future<void> humanDelete(int hid) => humans.delete(hid);
  Future<String> humanRevealRrn({required int hid, required String reason}) =>
      humans.revealRrn(hid: hid, reason: reason);
  Future<String> humanRevealHphone(
          {required int hid, required String reason}) =>
      humans.revealHphone(hid: hid, reason: reason);
  Future<String> humanRevealLinkedPhone(
          {required int hid, required String reason}) =>
      humans.revealLinkedPhone(hid: hid, reason: reason);
  Future<String> humanRevealBankAccount(
          {required int hid, required String reason}) =>
      humans.revealBankAccount(hid: hid, reason: reason);

  Future<List<HumanRead>> humanGetPlaceRecentWorkers({
    required int pid,
    int limit = 100,
    int offset = 0,
  }) =>
      humans.getPlaceRecentWorkers(pid: pid, limit: limit, offset: offset);

  Future<List<PlaceWorkDayRead>> placeWorkDaysList() => placeWorkDays.list();
  Future<List<PlaceWorkDayRead>> placeWorkDaysQuery(ListQuery query) =>
      placeWorkDays.listAll(query);
  Future<PlaceWorkDayRead> placeWorkDayGet(int pwdid) =>
      placeWorkDays.get(pwdid);
  Future<PlaceWorkDayRead> placeWorkDayCreate(Map<String, dynamic> body) =>
      placeWorkDays.create(body);
  Future<PlaceWorkDayRead> placeWorkDayPatch(
    int pwdid,
    Map<String, dynamic> body,
  ) =>
      placeWorkDays.patch(pwdid, body);
  Future<void> placeWorkDayDelete(int pwdid) => placeWorkDays.delete(pwdid);

  Future<PlaceWorkDayInstructionBundle> placeWorkDayInstructionBundle({
    required int pid,
    required String workdate,
  }) =>
      placeWorkDayInstructions.getBundle(pid: pid, workdate: workdate);

  Future<void> placeWorkDaySiteInstructionUpsert({
    required int pid,
    required String workdate,
    required List<WorkerAnnouncementBlock> blocks,
  }) =>
      placeWorkDayInstructions.upsertSite(
        pid: pid,
        workdate: workdate,
        blocks: blocks,
      );

  Future<void> placeWorkDayProcessInstructionUpsert({
    required int pid,
    required String workdate,
    required String workrole,
    required List<WorkerAnnouncementBlock> blocks,
  }) =>
      placeWorkDayInstructions.upsertProcess(
        pid: pid,
        workdate: workdate,
        workrole: workrole,
        blocks: blocks,
      );

  Future<List<WorkCostRead>> workCostsList() => workCosts.list();
  Future<List<WorkCostRead>> workCostsQuery(ListQuery query) =>
      workCosts.listAll(query);
  Future<WorkCostPeriodTotals?> workCostsPeriodTotals(ListQuery query) =>
      workCosts.fetchPeriodTotals(query);
  Future<PagedResult<WorkCostWorkerSummary>?> workCostsWorkerSummariesPage(
    ListQuery query,
  ) =>
      workCosts.fetchWorkerSummariesPage(query);
  Future<WorkCostRead> workCostGet(int wid) => workCosts.get(wid);
  Future<WorkCostRead> workCostCreate(Map<String, dynamic> body) =>
      workCosts.create(body);
  Future<WorkCostRead> workCostPatch(int wid, Map<String, dynamic> body) =>
      workCosts.patch(wid, body);
  Future<void> workCostCompletePatch(int wid, int wcomplete) =>
      workCosts.patchComplete(wid, wcomplete);
  Future<void> workCostDelete(int wid) => workCosts.delete(wid);

  Future<List<MaterialCostRead>> materialCostsList() => materialCosts.list();
  Future<List<MaterialCostRead>> materialCostsQuery(ListQuery query) =>
      materialCosts.listAll(query);
  Future<MaterialCostRead> materialCostGet(int mid) => materialCosts.get(mid);
  Future<MaterialCostRead> materialCostCreate(Map<String, dynamic> body) =>
      materialCosts.create(body);
  Future<MaterialCostRead> materialCostPatch(
          int mid, Map<String, dynamic> body) =>
      materialCosts.patch(mid, body);
  Future<void> materialCostDelete(int mid) => materialCosts.delete(mid);

  Future<List<PlaceRevenueRead>> placeRevenuesList() => placeRevenues.list();
  Future<List<PlaceRevenueRead>> placeRevenuesQuery(ListQuery query) =>
      placeRevenues.listAll(query);
  Future<PlaceRevenueRead> placeRevenueGet(int rid) => placeRevenues.get(rid);
  Future<PlaceRevenueRead> placeRevenueCreate(Map<String, dynamic> body) =>
      placeRevenues.create(body);
  Future<PlaceRevenueRead> placeRevenuePatch(
    int rid,
    Map<String, dynamic> body,
  ) =>
      placeRevenues.patch(rid, body);
  Future<void> placeRevenueDelete(int rid) => placeRevenues.delete(rid);

  Future<List<PlaceWorkerRecentRead>> placeWorkerRecentsList() =>
      placeWorkerRecents.list();
  Future<PlaceWorkerRecentRead> placeWorkerRecentGet(int pid, int hid) =>
      placeWorkerRecents.get(pid, hid);
  Future<PlaceWorkerRecentRead> placeWorkerRecentCreate(
    Map<String, dynamic> body,
  ) =>
      placeWorkerRecents.create(body);
  Future<PlaceWorkerRecentRead> placeWorkerRecentPatch(
    int pid,
    int hid,
    Map<String, dynamic> body,
  ) =>
      placeWorkerRecents.patch(pid, hid, body);
  Future<void> placeWorkerRecentDelete(int pid, int hid) =>
      placeWorkerRecents.delete(pid, hid);

  Future<List<ScheduleMemoRead>> scheduleMemosList() => scheduleMemos.list();
  Future<List<ScheduleMemoRead>> scheduleMemosQuery(ListQuery query) =>
      scheduleMemos.listAll(query);
  Future<PagedResult<ScheduleMemoRead>> scheduleMemosQueryPage(
    ListQuery query,
  ) =>
      scheduleMemos.listPage(query);
  Future<ScheduleMemoRead> scheduleMemoGet(int sid) => scheduleMemos.get(sid);
  Future<ScheduleMemoRead> scheduleMemoCreate(Map<String, dynamic> body) =>
      scheduleMemos.create(body);
  Future<ScheduleMemoRead> scheduleMemoPatch(
    int sid,
    Map<String, dynamic> body,
  ) =>
      scheduleMemos.patch(sid, body);
  Future<void> scheduleMemoDelete(int sid) => scheduleMemos.delete(sid);

  Future<List<PlacePhotoGroupRead>> placePhotoGroupsList() =>
      placePhotoGroups.list();
  Future<PlacePhotoGroupRead> placePhotoGroupGet(int pgid) =>
      placePhotoGroups.get(pgid);
  Future<PlacePhotoGroupRead> placePhotoGroupCreate(
    Map<String, dynamic> body,
  ) =>
      placePhotoGroups.create(body);
  Future<PlacePhotoGroupRead> placePhotoGroupPatch(
    int pgid,
    Map<String, dynamic> body,
  ) =>
      placePhotoGroups.patch(pgid, body);
  Future<void> placePhotoGroupDelete(int pgid) => placePhotoGroups.delete(pgid);

  Future<List<PlacePhotoRead>> placePhotosList() => placePhotos.list();
  Future<PlacePhotoRead> placePhotoGet(int phid) => placePhotos.get(phid);
  Future<PlacePhotoRead> placePhotoCreate(Map<String, dynamic> body) =>
      placePhotos.create(body);
  Future<PlacePhotoRead> placePhotoPatch(int phid, Map<String, dynamic> body) =>
      placePhotos.patch(phid, body);
  Future<void> placePhotoDelete(int phid) => placePhotos.delete(phid);

  Future<List<WorkerMgmtNoteRead>> workerMgmtNotesList(int workerHid) =>
      workerManagement.listNotes(workerHid);
  Future<PagedResult<WorkerMgmtNoteRead>> workerMgmtNotesPage(
    int workerHid, {
    int limit = kListPageSize,
    String? cursor,
  }) =>
      workerManagement.listNotesPage(workerHid, limit: limit, cursor: cursor);
  Future<WorkerMgmtNoteRead> workerMgmtNoteCreate({
    required int workerHid,
    required String noteType,
    required String memo,
    int? rating,
  }) =>
      workerManagement.createNote(
        workerHid: workerHid,
        noteType: noteType,
        memo: memo,
        rating: rating,
      );
  Future<List<WorkerMgmtConflictRead>> workerMgmtConflictsList({
    bool activeOnly = true,
  }) =>
      workerManagement.listConflicts(activeOnly: activeOnly);
  Future<PagedResult<WorkerMgmtConflictRead>> workerMgmtConflictsPage({
    bool activeOnly = true,
    int limit = kListPageSize,
    String? cursor,
  }) =>
      workerManagement.listConflictsPage(
        activeOnly: activeOnly,
        limit: limit,
        cursor: cursor,
      );
  Future<WorkerMgmtConflictRead> workerMgmtConflictUpsert({
    required int workerAHid,
    required int workerBHid,
    int severity = 2,
    String note = '',
    bool active = true,
  }) =>
      workerManagement.upsertConflict(
        workerAHid: workerAHid,
        workerBHid: workerBHid,
        severity: severity,
        note: note,
        active: active,
      );
  Future<void> workerMgmtConflictDelete(int pairId) =>
      workerManagement.deleteConflict(pairId);

  Future<Map<String, dynamic>> placesBulkAssignWorkforce({
    required int pid,
    required Map<String, dynamic> body,
  }) =>
      places.bulkAssignWorkforce(pid: pid, body: body);
}
