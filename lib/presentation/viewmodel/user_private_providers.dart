import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/users/user_private_api.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/data/model/user_private_models.dart';
import 'package:w0001/domain/use_case/user_private_use_case.dart';
import 'package:w0001/presentation/viewmodel/terms_providers.dart';

final userPrivateApiProvider = Provider<UserPrivateRemoteApi>(
  (ref) => UserPrivateRemoteApi(AppHttpClient.I),
);

final userPrivateUseCaseProvider = Provider<UserPrivateUseCase>(
  (ref) => UserPrivateUseCase(ref.read(userPrivateApiProvider)),
);

final workerPrivateInfoProvider =
    AsyncNotifierProvider<WorkerPrivateInfoNotifier, UserPrivateRead?>(
  WorkerPrivateInfoNotifier.new,
);

class WorkerPrivateInfoNotifier extends AsyncNotifier<UserPrivateRead?> {
  @override
  Future<UserPrivateRead?> build() async {
    try {
      return await ref.read(userPrivateUseCaseProvider).getMine();
    } catch (_) {
      return null;
    }
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(() async {
      return ref.read(userPrivateUseCaseProvider).getMine();
    });
  }

  Future<UserPrivateRead> save({
    String? rrn,
    String? bankAccount,
    String? bankOwner,
    String? bankName,
    int? workerTaxTermId,
    String? workerTaxTermVersion,
  }) async {
    final saved = await ref.read(userPrivateUseCaseProvider).saveMine(
          rrn: rrn,
          bankAccount: bankAccount,
          bankOwner: bankOwner,
          bankName: bankName,
          workerTaxTermId: workerTaxTermId,
          workerTaxTermVersion: workerTaxTermVersion,
        );
    state = AsyncData(saved);
    return saved;
  }
}

/// 세무정보 입력용 `worker_tax` 약관.
final workerTaxTermProvider = FutureProvider<TermSummary?>((ref) async {
  final latest = await ref.read(termsApiProvider).listLatest();
  for (final t in latest) {
    if (t.type == TermType.workerTax) return t;
  }
  return null;
});
