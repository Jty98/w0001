import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/auth/users_api.dart';
import 'package:w0001/data/datasources/remote/cost/material_costs_api.dart';
import 'package:w0001/data/datasources/remote/cost/work_costs_api.dart';
import 'package:w0001/data/datasources/remote/human/humans_api.dart';
import 'package:w0001/data/datasources/remote/place/place_collections_api.dart';
import 'package:w0001/data/datasources/remote/place/place_photo_groups_api.dart';
import 'package:w0001/data/datasources/remote/place/place_photos_api.dart';
import 'package:w0001/data/datasources/remote/place/place_revenues_api.dart';
import 'package:w0001/data/datasources/remote/place/place_work_days_api.dart';
import 'package:w0001/data/datasources/remote/place/place_worker_recents_api.dart';
import 'package:w0001/data/datasources/remote/place/places_api.dart';
import 'package:w0001/data/datasources/remote/schedule_memo/schedule_memos_api.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';

/// `require_super_admin` CRUD. 기능별 [UsersRemoteApi] 등에 위임한다.
final class SuperAdminRemoteApi {
  SuperAdminRemoteApi(AppHttpClient http)
      : users = UsersRemoteApi(http),
        places = PlacesRemoteApi(http),
        humans = HumansRemoteApi(http),
        placeWorkDays = PlaceWorkDaysRemoteApi(http),
        workCosts = WorkCostsRemoteApi(http),
        materialCosts = MaterialCostsRemoteApi(http),
        placeRevenues = PlaceRevenuesRemoteApi(http),
        placeCollections = PlaceCollectionsRemoteApi(http),
        placeWorkerRecents = PlaceWorkerRecentsRemoteApi(http),
        scheduleMemos = ScheduleMemosRemoteApi(http),
        placePhotoGroups = PlacePhotoGroupsRemoteApi(http),
        placePhotos = PlacePhotosRemoteApi(http);

  final UsersRemoteApi users;
  final PlacesRemoteApi places;
  final HumansRemoteApi humans;
  final PlaceWorkDaysRemoteApi placeWorkDays;
  final WorkCostsRemoteApi workCosts;
  final MaterialCostsRemoteApi materialCosts;
  final PlaceRevenuesRemoteApi placeRevenues;
  final PlaceCollectionsRemoteApi placeCollections;
  final PlaceWorkerRecentsRemoteApi placeWorkerRecents;
  final ScheduleMemosRemoteApi scheduleMemos;
  final PlacePhotoGroupsRemoteApi placePhotoGroups;
  final PlacePhotosRemoteApi placePhotos;

  // --- 퍼블릭 API (Repository 와 동일 시그니처) ---

  Future<List<UserRead>> usersList() => users.list();
  Future<UserRead> userGet(String uid) => users.get(uid);
  Future<UserRead> userCreate(UserCreateBody body) => users.create(body);
  Future<UserRead> userPatch(String uid, Map<String, dynamic> body) =>
      users.patch(uid, body);
  Future<void> userDelete(String uid) => users.delete(uid);

  Future<List<UserRead>> usersPendingList({String? q}) => users.listPending(q: q);
  Future<List<UserRead>> usersSearch({
    String? role,
    String? approvalStatus,
    bool? isActive,
    String? q,
  }) =>
      users.search(
        role: role,
        approvalStatus: approvalStatus,
        isActive: isActive,
        q: q,
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
  Future<PlaceRead> placeCreate(Map<String, dynamic> body) => places.create(body);
  Future<PlaceRead> placePatch(int pid, Map<String, dynamic> body) =>
      places.patch(pid, body);
  Future<void> placeDelete(int pid) => places.delete(pid);

  Future<List<HumanRead>> humansList() => humans.list();
  Future<HumanRead> humanGet(int hid) => humans.get(hid);
  Future<HumanRead> humanCreate(Map<String, dynamic> body) => humans.create(body);
  Future<HumanRead> humanPatch(int hid, Map<String, dynamic> body) =>
      humans.patch(hid, body);
  Future<void> humanDelete(int hid) => humans.delete(hid);

  Future<List<PlaceWorkDayRead>> placeWorkDaysList() => placeWorkDays.list();
  Future<PlaceWorkDayRead> placeWorkDayGet(int pwdid) => placeWorkDays.get(pwdid);
  Future<PlaceWorkDayRead> placeWorkDayCreate(Map<String, dynamic> body) =>
      placeWorkDays.create(body);
  Future<PlaceWorkDayRead> placeWorkDayPatch(
    int pwdid,
    Map<String, dynamic> body,
  ) =>
      placeWorkDays.patch(pwdid, body);
  Future<void> placeWorkDayDelete(int pwdid) => placeWorkDays.delete(pwdid);

  Future<List<WorkCostRead>> workCostsList() => workCosts.list();
  Future<WorkCostRead> workCostGet(int wid) => workCosts.get(wid);
  Future<WorkCostRead> workCostCreate(Map<String, dynamic> body) =>
      workCosts.create(body);
  Future<WorkCostRead> workCostPatch(int wid, Map<String, dynamic> body) =>
      workCosts.patch(wid, body);
  Future<void> workCostDelete(int wid) => workCosts.delete(wid);

  Future<List<MaterialCostRead>> materialCostsList() => materialCosts.list();
  Future<MaterialCostRead> materialCostGet(int mid) => materialCosts.get(mid);
  Future<MaterialCostRead> materialCostCreate(Map<String, dynamic> body) =>
      materialCosts.create(body);
  Future<MaterialCostRead> materialCostPatch(int mid, Map<String, dynamic> body) =>
      materialCosts.patch(mid, body);
  Future<void> materialCostDelete(int mid) => materialCosts.delete(mid);

  Future<List<PlaceRevenueRead>> placeRevenuesList() => placeRevenues.list();
  Future<PlaceRevenueRead> placeRevenueGet(int rid) => placeRevenues.get(rid);
  Future<PlaceRevenueRead> placeRevenueCreate(Map<String, dynamic> body) =>
      placeRevenues.create(body);
  Future<PlaceRevenueRead> placeRevenuePatch(
    int rid,
    Map<String, dynamic> body,
  ) =>
      placeRevenues.patch(rid, body);
  Future<void> placeRevenueDelete(int rid) => placeRevenues.delete(rid);

  Future<List<PlaceCollectionRead>> placeCollectionsList() =>
      placeCollections.list();
  Future<PlaceCollectionRead> placeCollectionGet(int cid) =>
      placeCollections.get(cid);
  Future<PlaceCollectionRead> placeCollectionCreate(Map<String, dynamic> body) =>
      placeCollections.create(body);
  Future<PlaceCollectionRead> placeCollectionPatch(
    int cid,
    Map<String, dynamic> body,
  ) =>
      placeCollections.patch(cid, body);
  Future<void> placeCollectionDelete(int cid) => placeCollections.delete(cid);

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
}
