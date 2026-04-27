import 'package:shared_preferences/shared_preferences.dart';

const _kAutoLogin = 'auth_pref_auto_login';
const _kSaveId = 'auth_pref_save_id';
const _kSavedUid = 'auth_pref_saved_uid';

class LoginPreferencesData {
  const LoginPreferencesData({
    required this.autoLogin,
    required this.saveId,
    this.savedUid,
  });

  final bool autoLogin;
  final bool saveId;
  final String? savedUid;
}

/// 로그인 화면: 자동 로그인·아이디 저장 여부·저장된 아이디(선택)
final class LoginPreferences {
  LoginPreferences._();

  static Future<LoginPreferencesData> load() async {
    final p = await SharedPreferences.getInstance();
    return LoginPreferencesData(
      autoLogin: p.getBool(_kAutoLogin) ?? false,
      saveId: p.getBool(_kSaveId) ?? false,
      savedUid: p.getString(_kSavedUid),
    );
  }

  /// 로그인 성공 직후 호출: 자동 로그인 플래그, 아이디 저장 시 uid 유지/미저장 시 삭제
  static Future<void> applyAfterSuccess({
    required bool autoLogin,
    required bool saveId,
    required String currentUid,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAutoLogin, autoLogin);
    await p.setBool(_kSaveId, saveId);
    if (saveId && currentUid.isNotEmpty) {
      await p.setString(_kSavedUid, currentUid);
    } else {
      await p.remove(_kSavedUid);
    }
  }
}
