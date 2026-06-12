import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/place/place_site_guide_api.dart';
import 'package:w0001/data/model/place_site_guide_model.dart';
import 'package:w0001/data/repository/place_site_guide_repository_impl.dart';
import 'package:w0001/domain/repository/place_site_guide_repository.dart';
import 'package:w0001/util/place_site_guide_messages.dart';

class PlaceSiteGuideByPidState {
  const PlaceSiteGuideByPidState({
    this.guide,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.accessDenied = false,
    this.loadGeneration = 0,
    this.hasLoadedOnce = false,
  });

  final PlaceSiteGuideModel? guide;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final bool accessDenied;

  /// [load] 호출마다 증가 — 다이얼로그가 어느 fetch 결과를 폼에 반영했는지 구분.
  final int loadGeneration;
  final bool hasLoadedOnce;

  PlaceSiteGuideByPidState copyWith({
    PlaceSiteGuideModel? guide,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool? accessDenied,
    int? loadGeneration,
    bool? hasLoadedOnce,
    bool clearError = false,
  }) {
    return PlaceSiteGuideByPidState(
      guide: guide ?? this.guide,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      accessDenied: accessDenied ?? this.accessDenied,
      loadGeneration: loadGeneration ?? this.loadGeneration,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
    );
  }
}

final placeSiteGuideApiProvider = Provider<PlaceSiteGuideRemoteApi>(
  (ref) => PlaceSiteGuideRemoteApi(AppHttpClient.I),
);

final placeSiteGuideRepositoryProvider = Provider<PlaceSiteGuideRepository>(
  (ref) => PlaceSiteGuideRepositoryImpl(ref.read(placeSiteGuideApiProvider)),
);

final placeSiteGuideByPidProvider = NotifierProvider.family<
    PlaceSiteGuideByPidNotifier,
    PlaceSiteGuideByPidState,
    int>(
  PlaceSiteGuideByPidNotifier.new,
);

class PlaceSiteGuideByPidNotifier extends Notifier<PlaceSiteGuideByPidState> {
  PlaceSiteGuideByPidNotifier(this.pid);

  final int pid;

  @override
  PlaceSiteGuideByPidState build() => const PlaceSiteGuideByPidState();

  PlaceSiteGuideRepository get _repo =>
      ref.read(placeSiteGuideRepositoryProvider);

  Future<void> load() async {
    final generation = state.loadGeneration + 1;
    state = PlaceSiteGuideByPidState(
      guide: state.guide,
      isLoading: true,
      loadGeneration: generation,
      hasLoadedOnce: state.hasLoadedOnce,
      accessDenied: false,
    );
    try {
      final fetched = await _repo.fetch(pid);
      state = PlaceSiteGuideByPidState(
        guide: fetched ?? PlaceSiteGuideModel.empty(pid),
        isLoading: false,
        loadGeneration: generation,
        hasLoadedOnce: true,
      );
    } catch (e) {
      final msg = placeSiteGuideUserMessage(
        e,
        fallback: '인수인계를 불러오지 못했습니다.',
      );
      final denied = e is HttpStatusException && e.statusCode == 403;
      state = PlaceSiteGuideByPidState(
        isLoading: false,
        errorMessage: msg,
        accessDenied: denied,
        guide: denied ? null : PlaceSiteGuideModel.empty(pid),
        loadGeneration: generation,
        hasLoadedOnce: true,
      );
    }
  }

  /// 다이얼로그 저장 — PUT 전체 교체.
  Future<bool> save(PlaceSiteGuideModel draft) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final saved = await _repo.save(pid, draft);
      state = PlaceSiteGuideByPidState(
        guide: saved,
        isSaving: false,
        loadGeneration: state.loadGeneration,
        hasLoadedOnce: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: placeSiteGuideUserMessage(
          e,
          fallback: '저장에 실패했습니다. 네트워크를 확인해 주세요.',
        ),
      );
      return false;
    }
  }
}
