/// HTTP **경로만** (leading slash, `baseUrl` 제외).
///
/// [AppHttpClient]·[AuthApi]·슈퍼관리자 원격 API에서 공통 사용.
abstract final class ApiEndpoint {
  // --- Auth ---
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authMe = '/auth/me';
  static const String authLogout = '/auth/logout';

  // --- Users ---
  static const String users = '/users';
  static String usersUid(String uid) =>
      '$users/${Uri.encodeComponent(uid)}';

  // --- Places ---
  static const String places = '/places';
  static String placesPid(int pid) => '$places/$pid';

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
