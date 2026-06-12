import 'package:flutter/material.dart';
import 'package:w0001/data/datasources/remote/auth_token_storage.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/navigation/app_router.dart';
import 'package:w0001/navigation/pending_post_auth_navigation.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/util/clear_user_providers.dart';
import 'package:w0001/util/fetch_data.dart';

Future<void>? _forcedSignOutInFlight;
DateTime? _lastForcedSignOutSnackAt;

const _forcedSignOutSnackThrottle = Duration(seconds: 12);

/// [AppHttpClient] 인터셉터 등에서 토큰 삭제 후 로그인 화면으로 보낼 때 호출.
///
/// 동시에 여러 API가 401이어도 처리·스낵바는 한 번만 수행한다.
Future<void> performAuthForcedSignOut(String userMessage) {
  return _forcedSignOutInFlight ??= _runForcedSignOut(userMessage).whenComplete(() {
    _forcedSignOutInFlight = null;
  });
}

Future<void> _runForcedSignOut(String userMessage) async {
  await AuthTokenStorage.I.clear();
  await PendingPostAuthNavigation.clear();

  final container = rootProviderContainer;
  if (container != null) {
    clearAllUserProviders(container);
    container.read(authSessionProvider.notifier).clearSession();
  }

  appBoundGoRouter?.go('/login');
  _showForcedSignOutSnackBarOnce(userMessage);
}

void _showForcedSignOutSnackBarOnce(String message) {
  final now = DateTime.now();
  if (_lastForcedSignOutSnackAt != null &&
      now.difference(_lastForcedSignOutSnackAt!) < _forcedSignOutSnackThrottle) {
    return;
  }
  _lastForcedSignOutSnackAt = now;

  final navKey = AppHttpClient.rootNavigatorKey;
  final ctx = navKey?.currentContext;
  if (ctx == null) return;
  final messenger = ScaffoldMessenger.maybeOf(ctx);
  if (messenger == null) return;

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );
}

/// 로그인 성공 후 같은 메시지 스낵바 억제 타이머를 초기화한다.
void resetForcedSignOutSnackThrottle() {
  _lastForcedSignOutSnackAt = null;
}
