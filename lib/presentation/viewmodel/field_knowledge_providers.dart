import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/field_knowledge_api.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/field_knowledge_models.dart';
import 'package:w0001/data/repository/field_knowledge_repository_impl.dart';
import 'package:w0001/domain/repository/field_knowledge_repository.dart';

// ────────────────────────────────────────────────────────────────────────────
// Repository Provider
// ────────────────────────────────────────────────────────────────────────────

final fieldKnowledgeApiProvider = Provider<FieldKnowledgeApi>((ref) {
  return FieldKnowledgeApi(AppHttpClient.I);
});

final fieldKnowledgeRepositoryProvider =
    Provider<FieldKnowledgeRepository>((ref) {
  final api = ref.watch(fieldKnowledgeApiProvider);
  return FieldKnowledgeRepositoryImpl(api);
});

// ────────────────────────────────────────────────────────────────────────────
// State
// ────────────────────────────────────────────────────────────────────────────

class FieldKnowledgeListState {
  const FieldKnowledgeListState({
    this.items = const [],
    this.filter = const KnowledgeFilter(),
    this.page = 1,
    this.total = 0,
    this.hasNext = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSaving = false,
    this.error,
  });

  final List<KnowledgeEntry> items;
  final KnowledgeFilter filter;
  final int page;
  final int total;
  final bool hasNext;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSaving;
  final String? error;

  FieldKnowledgeListState copyWith({
    List<KnowledgeEntry>? items,
    KnowledgeFilter? filter,
    int? page,
    int? total,
    bool? hasNext,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSaving,
    String? error,
  }) {
    return FieldKnowledgeListState(
      items: items ?? this.items,
      filter: filter ?? this.filter,
      page: page ?? this.page,
      total: total ?? this.total,
      hasNext: hasNext ?? this.hasNext,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Notifier
// ────────────────────────────────────────────────────────────────────────────

class FieldKnowledgeListNotifier extends Notifier<FieldKnowledgeListState> {
  FieldKnowledgeListNotifier();

  late final FieldKnowledgeRepository _repository;

  @override
  FieldKnowledgeListState build() {
    _repository = ref.watch(fieldKnowledgeRepositoryProvider);
    return const FieldKnowledgeListState();
  }

  static const int _pageSize = 20;

  /// 초기 로드
  Future<void> load({KnowledgeFilter? filter}) async {
    final newFilter = filter ?? state.filter;
    state = state.copyWith(
      isLoading: true,
      error: null,
      filter: newFilter,
      page: 1,
    );

    try {
      final result = await _repository.getEntries(
        filter: newFilter,
        page: 1,
        pageSize: _pageSize,
      );
      state = state.copyWith(
        items: result.items,
        page: result.page,
        total: result.total,
        hasNext: result.hasNext,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '데이터를 불러오지 못했습니다: $e',
      );
    }
  }

  /// 다음 페이지 로드
  Future<void> loadMore() async {
    if (!state.hasNext || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final nextPage = state.page + 1;
      final result = await _repository.getEntries(
        filter: state.filter,
        page: nextPage,
        pageSize: _pageSize,
      );
      state = state.copyWith(
        items: [...state.items, ...result.items],
        page: result.page,
        total: result.total,
        hasNext: result.hasNext,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: '추가 데이터를 불러오지 못했습니다: $e',
      );
    }
  }

  /// 필터 변경
  void setFilter(KnowledgeFilter filter) {
    load(filter: filter);
  }

  /// 검색
  void search(String query) {
    final newFilter = state.filter.copyWith(query: query);
    load(filter: newFilter);
  }

  /// 용어사전 초성 필터 (`initial`). null 이면 전체.
  void setInitial(String? initial) {
    final trimmed = initial?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    load(filter: state.filter.copyWith(initial: value));
  }

  /// 항목 저장 (생성/수정)
  Future<bool> saveEntry(KnowledgeEntry entry) async {
    state = state.copyWith(isSaving: true, error: null);

    try {
      final saved = entry.id == 0
          ? await _repository.createEntry(entry)
          : await _repository.updateEntry(entry);

      // 리스트에 반영
      final updatedItems = entry.id == 0
          ? [saved, ...state.items]
          : state.items.map((e) => e.id == saved.id ? saved : e).toList();

      state = state.copyWith(
        items: updatedItems,
        isSaving: false,
      );
      // 상세 화면 캐시 무효화
      ref.invalidate(fieldKnowledgeEntryProvider(saved.id));
      ref.invalidate(fieldKnowledgeRelatedEntriesProvider(saved.id));
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: '저장하지 못했습니다: $e',
      );
      return false;
    }
  }

  /// 항목 삭제
  Future<bool> deleteEntry(int id) async {
    state = state.copyWith(isSaving: true, error: null);

    try {
      final ok = await _repository.deleteEntry(id);
      if (ok) {
        state = state.copyWith(
          items: state.items.where((e) => e.id != id).toList(),
          isSaving: false,
        );
        ref.invalidate(fieldKnowledgeEntryProvider(id));
        ref.invalidate(fieldKnowledgeRelatedEntriesProvider(id));
      } else {
        state = state.copyWith(
          isSaving: false,
          error: '삭제하지 못했습니다.',
        );
      }
      return ok;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: '삭제하지 못했습니다: $e',
      );
      return false;
    }
  }
}

final fieldKnowledgeListProvider = NotifierProvider.autoDispose<
    FieldKnowledgeListNotifier, FieldKnowledgeListState>(
  FieldKnowledgeListNotifier.new,
);

// ────────────────────────────────────────────────────────────────────────────
// 단일 항목 상세 Provider
// ────────────────────────────────────────────────────────────────────────────

final fieldKnowledgeEntryProvider =
    FutureProvider.autoDispose.family<KnowledgeEntry?, int>((ref, id) async {
  final repository = ref.watch(fieldKnowledgeRepositoryProvider);
  return await repository.getEntry(id);
});

// ────────────────────────────────────────────────────────────────────────────
// 연관 항목 Provider (상세 조회 시 포함되므로 선택적 사용)
// ────────────────────────────────────────────────────────────────────────────

final fieldKnowledgeRelatedEntriesProvider = FutureProvider.autoDispose
    .family<List<KnowledgeEntry>, int>((ref, id) async {
  // 상세 조회 시 이미 포함되어 있으므로, 별도 호출은 선택적
  // 만약 상세 조회를 안 했거나 추가 연관 항목이 필요한 경우에만 사용
  final repository = ref.watch(fieldKnowledgeRepositoryProvider);
  return await repository.getRelatedEntries(id, limit: 5);
});

// ────────────────────────────────────────────────────────────────────────────
// 태그 Provider
// ────────────────────────────────────────────────────────────────────────────

final fieldKnowledgeTagsProvider = FutureProvider.autoDispose
    .family<List<KnowledgeTagStats>, KnowledgeEntryType?>((ref, type) async {
  final repository = ref.watch(fieldKnowledgeRepositoryProvider);
  return await repository.getTags(type: type);
});
