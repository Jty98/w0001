/// HTTP **경로만** (leading slash, `baseUrl` 제외).
///
/// [AppHttpClient]·[AuthApi]·슈퍼관리자 원격 API에서 공통 사용.
abstract final class ApiEndpoint {
  // --- Uploads (Bearer, 일반 사용자) ---
  static const String uploadsImage = '/uploads/image';

  // --- Auth ---
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authSignup = '/auth/signup';
  static const String authMe = '/auth/me';
  static const String authLogout = '/auth/logout';
  static const String authVerifySensitiveAction = '/auth/verify-sensitive-action';

  /// [POST /users/.../suspend], [POST /users/.../role] 등 민감 작업 시 Bearer와 함께 전달.
  static const String headerAdminActionToken = 'X-Admin-Action-Token';

  // --- Users ---
  static const String users = '/users';
  static const String usersPending = '$users/pending';
  static const String usersSearch = '$users/search';
  static String usersUid(String uid) =>
      '$users/${Uri.encodeComponent(uid)}';

  static String usersUidApprove(String uid) =>
      '${usersUid(uid)}/approve';
  static String usersUidReject(String uid) =>
      '${usersUid(uid)}/reject';
  static String usersUidSuspend(String uid) =>
      '${usersUid(uid)}/suspend';
  static String usersUidActivate(String uid) =>
      '${usersUid(uid)}/activate';
  static String usersUidRole(String uid) =>
      '${usersUid(uid)}/role';

  // --- Places ---
  static const String places = '/places';
  static String placesPid(int pid) => '$places/$pid';
  static String placesProcessSchedule(int pid) =>
      '${placesPid(pid)}/process-schedule';

  // --- Humans ---
  static const String humans = '/humans';
  static String humansHid(int hid) => '$humans/$hid';

  // --- Place work days ---
  static const String placeWorkDays = '/place-work-days';
  static String placeWorkDaysId(int pwdid) => '$placeWorkDays/$pwdid';

  // --- Work costs ---
  static const String workCosts = '/work-costs';
  static String workCostsWid(int wid) => '$workCosts/$wid';

  // --- Material costs ---
  static const String materialCosts = '/material-costs';
  static String materialCostsMid(int mid) => '$materialCosts/$mid';

  // --- Place revenues ---
  static const String placeRevenues = '/place-revenues';
  static String placeRevenuesRid(int rid) => '$placeRevenues/$rid';

  // --- Place collections ---
  static const String placeCollections = '/place-collections';
  static String placeCollectionsCid(int cid) => '$placeCollections/$cid';

  // --- Place worker recents (복합 키) ---
  static const String placeWorkerRecents = '/place-worker-recents';
  static String placeWorkerRecentsPair(int pid, int hid) =>
      '$placeWorkerRecents/$pid/$hid';

  // --- Schedule memos ---
  static const String scheduleMemos = '/schedule-memos';
  static String scheduleMemosSid(int sid) => '$scheduleMemos/$sid';

  // --- Place photo groups ---
  static const String placePhotoGroups = '/place-photo-groups';
  static String placePhotoGroupsPgid(int pgid) => '$placePhotoGroups/$pgid';

  // --- Place photos ---
  static const String placePhotos = '/place-photos';
  static String placePhotosPhid(int phid) => '$placePhotos/$phid';

  /// 디스크 원본 바이너리 (Bearer, 일반 사용자). [inline] 은 쿼리로 `true`/`false`.
  static String placePhotosOriginalFile(int phid) =>
      '$placePhotos/$phid/original-file';

  // --- Dashboard (super_admin, aggregated) ---
  static const String dashboard = '/dashboard';
  static const String dashboardKpi = '$dashboard/kpi';
  static const String dashboardYearly = '$dashboard/yearly';
  static const String dashboardPlaces = '$dashboard/places';
  static const String dashboardMonthly = '$dashboard/monthly';
  static const String dashboardBundle = '$dashboard/bundle';
  static const String dashboardCalendarEvents = '$dashboard/calendar-events';
  static const String dashboardPlacesInfo = '$dashboard/places-info';
}
