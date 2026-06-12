import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/users/user_account_api.dart';
import 'package:w0001/data/model/user_account_models.dart';
import 'package:w0001/domain/use_case/user_account_use_case.dart';

final userAccountApiProvider = Provider<UserAccountRemoteApi>(
  (ref) => UserAccountRemoteApi(AppHttpClient.I),
);

final userAccountUseCaseProvider = Provider<UserAccountUseCase>(
  (ref) => UserAccountUseCase(ref.read(userAccountApiProvider)),
);

final userAccountProvider =
    AsyncNotifierProvider<UserAccountNotifier, UserAccountRead?>(
  UserAccountNotifier.new,
);

class UserAccountNotifier extends AsyncNotifier<UserAccountRead?> {
  @override
  Future<UserAccountRead?> build() async {
    try {
      return await ref.read(userAccountUseCaseProvider).getMine();
    } catch (_) {
      return null;
    }
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(userAccountUseCaseProvider).getMine(),
    );
  }

  Future<UserAccountRead> updateName(String uname) async {
    final saved = await ref.read(userAccountUseCaseProvider).updateName(uname);
    state = AsyncData(saved);
    return saved;
  }

  Future<UserAccountRead> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final saved = await ref.read(userAccountUseCaseProvider).updatePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
    state = AsyncData(saved);
    return saved;
  }

  Future<UserAccountRead> updatePhone({
    required String phone,
    required String phoneVerificationToken,
  }) async {
    final saved = await ref.read(userAccountUseCaseProvider).updatePhone(
          phone: phone,
          phoneVerificationToken: phoneVerificationToken,
        );
    state = AsyncData(saved);
    return saved;
  }
}
