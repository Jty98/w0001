import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/auth/auth_api.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/repository/auth_impl.dart';
import 'package:w0001/domain/repository/auth_abst.dart';
import 'package:w0001/domain/use_case/auth_use_case.dart';
import 'package:w0001/presentation/viewmodel/notification_settings_providers.dart';
import 'package:w0001/util/post_auth_warmup.dart';

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(AppHttpClient.I),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.read(authApiProvider)),
);

final authUseCaseProvider = Provider<AuthUseCase>(
  (ref) => AuthUseCase(ref.read(authRepositoryProvider)),
);

/// 앱 전역 **로그인 사용자** — [AuthUseCase.getCurrentUser] / GET `/auth/me` 결과.
///
/// * 로그인 직후 [AuthSessionNotifier.loadCurrentUser]로 채움
/// * 대시보드 최초 진입 시(토큰만 있고 아직 [UserRead]가 없을 때) 한 번 로드
/// * 로그아웃 시 [AuthSessionNotifier.clearSession]으로 비움
class AuthSessionNotifier extends Notifier<AsyncValue<UserRead?>> {
  @override
  AsyncValue<UserRead?> build() {
    return const AsyncData(null);
  }

  /// [awaitWarmUp]이 true이면 상황판·현장 등 역할별 데이터 preload가 끝난 뒤 반환한다.
  /// 자동 로그인·수동 로그인 직후 UI 진입 전에 await 하는 것을 권장한다.
  Future<void> loadCurrentUser({bool awaitWarmUp = false}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uc = ref.read(authUseCaseProvider);
      return uc.getCurrentUser();
    });
    if (state.hasError || state.asData?.value == null) return;

    final user = state.asData!.value!;
    final container = ref.container;
    if (awaitWarmUp) {
      await Future<void>.delayed(Duration.zero);
      await warmUpUserScopedData(container, user);
    } else {
      scheduleWarmUpUserScopedData(container, user);
    }
  }

  void clearSession() {
    state = const AsyncData(null);
    // 알림 설정 로컬 데이터 삭제 (백그라운드)
    unawaited(
      ref
          .read(notificationSettingsNotifierProvider.notifier)
          .clearLocal()
          .catchError((_) {}),
    );
  }
}

final authSessionProvider =
    NotifierProvider<AuthSessionNotifier, AsyncValue<UserRead?>>(
  AuthSessionNotifier.new,
);
