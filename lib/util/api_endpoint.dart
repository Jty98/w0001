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
  static const String authPhoneSendCode = '/auth/phone/send-code';
  static const String authPhoneVerify = '/auth/phone/verify';
  static const String authCheckUid = '/auth/check-uid';

  // --- Terms (공개) ---
  static const String terms = '/terms';
  static String termById(int id) => '$terms/$id';
  static const String authMe = '/auth/me';
  static const String authLogout = '/auth/logout';
  static const String authLogoutAll = '/auth/logout-all';
  static const String authVerifySensitiveAction =
      '/auth/verify-sensitive-action';

  /// [POST /users/.../suspend], [POST /users/.../role] 등 민감 작업 시 Bearer와 함께 전달.
  static const String headerAdminActionToken = 'X-Admin-Action-Token';

  // --- Users ---
  static const String users = '/users';
  static const String usersMeFcmDevice = '$users/me/fcm-device';

  /// 알림함 (`GET` 목록, `DELETE` 전체 삭제). 서버 미구현 시 404 — 앱은 FCM 로컬 폴백.
  static const String usersMeNotifications = '$users/me/notifications';
  static const String usersMeNotificationsUnreadCount =
      '$usersMeNotifications/unread-count';
  static String usersMeNotificationId(String id) =>
      '$usersMeNotifications/${Uri.encodeComponent(id)}';
  static String usersMeNotificationRead(String id) =>
      '${usersMeNotificationId(id)}/read';
  
  /// 알림 설정 (`GET` 조회, `PUT` 전체 업데이트, `PATCH` 부분 업데이트)
  static const String usersMeNotificationSettings = '$users/me/notification-settings';
  static const String usersPending = '$users/pending';
  static const String usersSearch = '$users/search';
  static String usersUid(String uid) => '$users/${Uri.encodeComponent(uid)}';

  static String usersUidApprove(String uid) => '${usersUid(uid)}/approve';
  static String usersUidReject(String uid) => '${usersUid(uid)}/reject';
  static String usersUidSuspend(String uid) => '${usersUid(uid)}/suspend';
  static String usersUidActivate(String uid) => '${usersUid(uid)}/activate';
  static String usersUidRole(String uid) => '${usersUid(uid)}/role';

  /// 워커 주특기·역할 ([UserRead]와 별도 프로필)
  /// 계정 기본 정보 (이름·비밀번호·휴대폰) — admin·worker 공통.
  static const String usersMeAccount = '$users/me/account';

  static const String usersMeWorkerProfile = '/users/me/worker-profile';
  static const String usersMePrivate = '$users/me/private';
  static const String usersMeTerms = '$users/me/terms';

  /// 관리자 — 작업자 세무·정산 정보 (마스킹).
  static String workersUidPrivate(String uid) =>
      '/workers/${Uri.encodeComponent(uid)}/private';

  /// 관리자 — 작업자 민감정보 전체 조회 (사유 필수).
  static String workersUidPrivateRrnReveal(String uid) =>
      '${workersUidPrivate(uid)}/rrn/reveal';
  static String workersUidPrivateBankReveal(String uid) =>
      '/workers/${Uri.encodeComponent(uid)}/private/bank/reveal';

  /// 관리자용 — [hid] 인력에 연결된 워커 프로필 (서버 구현 시).
  static String humansHidWorkerProfile(int hid) =>
      '${humansHid(hid)}/worker-profile';

  // --- Worker management (admin: 평가·메모·트러블) ---
  static const String workerManagementNotes = '/worker-management/notes';
  static String workerManagementNotesHid(int workerHid) =>
      '$workerManagementNotes/$workerHid';
  static const String workerManagementConflicts =
      '/worker-management/conflicts';
  static String workerManagementConflictPairId(int pairId) =>
      '$workerManagementConflicts/$pairId';

  /// 작업자 대상 공지 (`GET /worker-announcements/inbox` 수신함, 관리자 CRUD는 `/worker-announcements`).
  ///
  /// 서버가 아직 없으면 404 — UI는 빈 목록으로 처리.
  static const String workerAnnouncements = '/worker-announcements';
  static const String workerAnnouncementsInbox = '$workerAnnouncements/inbox';
  static String workerAnnouncementsId(int id) => '$workerAnnouncements/$id';

  // --- Places ---
  static const String places = '/places';

  /// 현재 계정에 허용된 현장만 (워커·스코프 admin 등). `GET /places`가 super_admin 전용일 때 사용.
  /// 응답: `PlaceRead[]` 또는 `{ "places": [...] }` 등.
  static const String placesMe = '$places/me';

  static String placesPid(int pid) => '$places/$pid';
  static String placesSiteGuide(int pid) => '${placesPid(pid)}/site-guide';
  static String placesProcessSchedule(int pid) =>
      '${placesPid(pid)}/process-schedule';

  // --- Worker-only (JWT role == worker; admin/super_admin → 403 WORKER_ROLE_REQUIRED)
  static const String workerPrefix = '/worker';
  static const String workerDashboardSummary =
      '$workerPrefix/dashboard/summary';

  /// `workdate`(YYYY-MM-DD) 쿼리 필수.
  static String workerPlaceCoworkersByDate(int pid) =>
      '$workerPrefix/places/$pid/coworkers-by-date';

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

  /// PDF·엑셀 등 비이미지 원본 (`multipart/form-data`, `file` + 메타).
  static const String placePhotosUpload = '$placePhotos/upload';

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
