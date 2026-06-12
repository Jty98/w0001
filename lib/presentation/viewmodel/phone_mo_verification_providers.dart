import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/phone_verification_models.dart';
import 'package:w0001/domain/use_case/phone_mo_verification_use_case.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';

final phoneMoVerificationUseCaseProvider = Provider<PhoneMoVerificationUseCase>(
  (ref) => PhoneMoVerificationUseCase(ref.read(authRepositoryProvider)),
);

final phoneMoVerificationNotifierProvider =
    NotifierProvider<PhoneMoVerificationNotifier, PhoneMoVerificationState>(
  PhoneMoVerificationNotifier.new,
);

class PhoneMoVerificationState {
  const PhoneMoVerificationState({
    this.sessionData,
    this.isLoading = false,
    this.error,
  });

  final PhoneMoStartResponse? sessionData;
  final bool isLoading;
  final String? error;

  PhoneMoVerificationState copyWith({
    PhoneMoStartResponse? sessionData,
    bool? isLoading,
    String? error,
  }) {
    return PhoneMoVerificationState(
      sessionData: sessionData ?? this.sessionData,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PhoneMoVerificationNotifier extends Notifier<PhoneMoVerificationState> {
  @override
  PhoneMoVerificationState build() => const PhoneMoVerificationState();

  PhoneMoVerificationUseCase get _useCase =>
      ref.read(phoneMoVerificationUseCaseProvider);

  Future<void> startVerification(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _useCase.start(phone);
      state = state.copyWith(
        sessionData: result,
        isLoading: false,
      );

      // SMS 앱 열기
      await _useCase.openSmsComposer(
        moNumber: result.moNumber,
        body: result.smsBody,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<String> waitForVerification(String phone) async {
    try {
      final token = await _useCase.waitUntilVerified(phone);
      state = state.copyWith(
        sessionData: null,
        isLoading: false,
      );
      return token;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  void reset() {
    state = const PhoneMoVerificationState();
  }
}

