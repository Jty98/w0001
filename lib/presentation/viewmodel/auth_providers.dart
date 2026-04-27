import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/auth/auth_api.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/repository/auth_impl.dart';
import 'package:w0001/domain/repository/auth_abst.dart';
import 'package:w0001/domain/use_case/auth_use_case.dart';

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

  Future<void> loadCurrentUser() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uc = ref.read(authUseCaseProvider);
      return uc.getCurrentUser();
    });
  }

  void clearSession() {
    state = const AsyncData(null);
  }
}

final authSessionProvider =
    NotifierProvider<AuthSessionNotifier, AsyncValue<UserRead?>>(
  AuthSessionNotifier.new,
);
