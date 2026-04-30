import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/auth_token_storage.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/util/login_preferences.dart';

/// 자동 로그인 설정이 켜져 있고 저장된 토큰이 있으면 세션을 복구합니다.
///
/// **선행 `POST /auth/refresh`를 호출하지 않습니다.**  
/// `GET /auth/me` 한 번으로 시작하고, 액세스 만료 시 [AppHttpClient] 인터셉터가 401 후 리프레시합니다.
///
/// [LoginPreferences.autoLogin]은 여전히 **실행 시점에 반드시 호출**되어야 첫 라우트가 바뀝니다.
Future<bool> tryRestoreSessionIfAutoLoginEnabled(ProviderContainer container) async {
  final prefs = await LoginPreferences.load();
  if (!prefs.autoLogin) return false;

  final rt = await AuthTokenStorage.I.readRefresh();
  final at = await AuthTokenStorage.I.readAccess();
  final hasCred =
      (rt != null && rt.isNotEmpty) || (at != null && at.isNotEmpty);
  if (!hasCred) return false;

  try {
    await container.read(authSessionProvider.notifier).loadCurrentUser();
    final s = container.read(authSessionProvider);
    if (s.hasError) return false;
    return s.maybeWhen(
      data: (u) => u != null,
      orElse: () => false,
    );
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('tryRestoreSessionIfAutoLoginEnabled: $e\n$st');
    }
    return false;
  }
}
