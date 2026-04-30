import 'dart:async';

/// [ProfileSuperAdminUserSection] 검색 디바운스 타이머 보관용.
final class ProfileSuperAdminSearchDebounceHolder {
  Timer? timer;

  void cancel() {
    timer?.cancel();
    timer = null;
  }
}
