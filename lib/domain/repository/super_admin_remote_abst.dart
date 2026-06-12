import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';

/// `super_admin` 전용 백엔드 CRUD (`require_super_admin` 가드).
///
/// [worker]/[admin] 는 403. 서비스 정책 변경 시 서버와 함께 맞출 것.
abstract class SuperAdminRemoteRepository {
  // Users
  Future<List<UserRead>> usersList();
  Future<UserRead> userGet(String uid);
  Future<UserRead> userCreate(UserCreateBody body);
  Future<UserRead> userPatch(String uid, Map<String, dynamic> body);
  Future<void> userDelete(String uid);

  /// 승인·활동·역할 (super_admin 전용)
  Future<List<UserRead>> usersPendingList({String? q});
  Future<List<UserRead>> usersSearch({
    String? role,
    String? approvalStatus,
    bool? isActive,
    String? q,
  });
  Future<void> userApprove(String uid, {String? note});
  Future<void> userReject(String uid, {String? note});
  Future<void> userSuspend(
    String uid, {
    String? reason,
    required String adminActionToken,
  });
  Future<void> userActivate(String uid);
  Future<UserRead> userChangeRole(
    String uid,
    UserRole role, {
    required String adminActionToken,
  });

  // Places
  Future<List<PlaceRead>> placesList();
  Future<PlaceRead> placeGet(int pid);
  Future<PlaceRead> placeCreate(Map<String, dynamic> body);
  Future<PlaceRead> placePatch(int pid, Map<String, dynamic> body);
  Future<void> placeDelete(int pid);

  // Humans
  Future<List<HumanRead>> humansList();
  Future<HumanRead> humanGet(int hid);
  Future<HumanRead> humanCreate(Map<String, dynamic> body);
  Future<HumanRead> humanPatch(int hid, Map<String, dynamic> body);
  Future<void> humanDelete(int hid);

  // Place work days
  Future<List<PlaceWorkDayRead>> placeWorkDaysList();
  Future<PlaceWorkDayRead> placeWorkDayGet(int pwdid);
  Future<PlaceWorkDayRead> placeWorkDayCreate(Map<String, dynamic> body);
  Future<PlaceWorkDayRead> placeWorkDayPatch(
    int pwdid,
    Map<String, dynamic> body,
  );
  Future<void> placeWorkDayDelete(int pwdid);

  // Work costs
  Future<List<WorkCostRead>> workCostsList();
  Future<WorkCostRead> workCostGet(int wid);
  Future<WorkCostRead> workCostCreate(Map<String, dynamic> body);
  Future<WorkCostRead> workCostPatch(int wid, Map<String, dynamic> body);
  Future<void> workCostDelete(int wid);

  // Material costs
  Future<List<MaterialCostRead>> materialCostsList();
  Future<MaterialCostRead> materialCostGet(int mid);
  Future<MaterialCostRead> materialCostCreate(Map<String, dynamic> body);
  Future<MaterialCostRead> materialCostPatch(
      int mid, Map<String, dynamic> body);
  Future<void> materialCostDelete(int mid);

  // Place revenues
  Future<List<PlaceRevenueRead>> placeRevenuesList();
  Future<PlaceRevenueRead> placeRevenueGet(int rid);
  Future<PlaceRevenueRead> placeRevenueCreate(Map<String, dynamic> body);
  Future<PlaceRevenueRead> placeRevenuePatch(
    int rid,
    Map<String, dynamic> body,
  );
  Future<void> placeRevenueDelete(int rid);

  // Place collections
  Future<List<PlaceCollectionRead>> placeCollectionsList();
  Future<PlaceCollectionRead> placeCollectionGet(int cid);
  Future<PlaceCollectionRead> placeCollectionCreate(Map<String, dynamic> body);
  Future<PlaceCollectionRead> placeCollectionPatch(
    int cid,
    Map<String, dynamic> body,
  );
  Future<void> placeCollectionDelete(int cid);

  // Place worker recents
  Future<List<PlaceWorkerRecentRead>> placeWorkerRecentsList();
  Future<PlaceWorkerRecentRead> placeWorkerRecentGet(int pid, int hid);
  Future<PlaceWorkerRecentRead> placeWorkerRecentCreate(
    Map<String, dynamic> body,
  );
  Future<PlaceWorkerRecentRead> placeWorkerRecentPatch(
    int pid,
    int hid,
    Map<String, dynamic> body,
  );
  Future<void> placeWorkerRecentDelete(int pid, int hid);

  // Schedule memos
  Future<List<ScheduleMemoRead>> scheduleMemosList();
  Future<ScheduleMemoRead> scheduleMemoGet(int sid);
  Future<ScheduleMemoRead> scheduleMemoCreate(Map<String, dynamic> body);
  Future<ScheduleMemoRead> scheduleMemoPatch(
    int sid,
    Map<String, dynamic> body,
  );
  Future<void> scheduleMemoDelete(int sid);

  // Place photo groups
  Future<List<PlacePhotoGroupRead>> placePhotoGroupsList();
  Future<PlacePhotoGroupRead> placePhotoGroupGet(int pgid);
  Future<PlacePhotoGroupRead> placePhotoGroupCreate(
    Map<String, dynamic> body,
  );
  Future<PlacePhotoGroupRead> placePhotoGroupPatch(
    int pgid,
    Map<String, dynamic> body,
  );
  Future<void> placePhotoGroupDelete(int pgid);

  // Place photos
  Future<List<PlacePhotoRead>> placePhotosList();
  Future<PlacePhotoRead> placePhotoGet(int phid);
  Future<PlacePhotoRead> placePhotoCreate(Map<String, dynamic> body);
  Future<PlacePhotoRead> placePhotoPatch(int phid, Map<String, dynamic> body);
  Future<void> placePhotoDelete(int phid);

  // Worker management (super_admin)
  Future<List<WorkerMgmtNoteRead>> workerMgmtNotesList(int workerHid);
  Future<WorkerMgmtNoteRead> workerMgmtNoteCreate({
    required int workerHid,
    required String noteType,
    required String memo,
    int? rating,
  });
  Future<List<WorkerMgmtConflictRead>> workerMgmtConflictsList({
    bool activeOnly = true,
  });
  Future<WorkerMgmtConflictRead> workerMgmtConflictUpsert({
    required int workerAHid,
    required int workerBHid,
    int severity = 2,
    String note = '',
    bool active = true,
  });
  Future<void> workerMgmtConflictDelete(int pairId);
}
