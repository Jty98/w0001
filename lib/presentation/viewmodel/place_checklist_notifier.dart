import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/place/place_checklist_api.dart';
import 'package:w0001/data/model/place_checklist_models.dart';
import 'package:w0001/data/repository/place_checklist_remote_repository.dart';
import 'package:w0001/domain/repository/place_checklist_repository.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';

final placeChecklistApiProvider = Provider<PlaceChecklistRemoteApi>(
  (ref) => PlaceChecklistRemoteApi(AppHttpClient.I),
);

final placeChecklistRepositoryProvider = Provider<PlaceChecklistRepository>(
  (ref) => PlaceChecklistRemoteRepository(ref.read(placeChecklistApiProvider)),
);

typedef PlaceChecklistFamilyArg = ({int pid, String pstart, String pend});

/// [load] 시 선택일 기준 ±[kFetchPaddingDays]일 범위를 서버에서 조회.
const kChecklistFetchPaddingDays = 90;

class PlaceChecklistState {
  const PlaceChecklistState({
    required this.selectedDate,
    required this.snapshot,
    required this.isLoading,
    this.error,
  });

  final DateTime selectedDate;
  final PlaceChecklistSnapshot? snapshot;
  final bool isLoading;
  final String? error;

  String get selectedDateKey => scheduleDateKey(scheduleDateOnly(selectedDate));

  List<PlaceChecklistItem> get dayItems {
    final snap = snapshot;
    if (snap == null) return const [];
    return snap.itemsForDate(selectedDateKey);
  }

  List<PlaceChecklistDeferral> get dayDeferrals {
    final snap = snapshot;
    if (snap == null) return const [];
    return snap.deferralsForDate(selectedDateKey);
  }

  int get checkedCount => dayItems.where((e) => e.isChecked).length;

  int get activeCount => dayItems.where((e) => !e.isDeferred).length;

  PlaceChecklistState copyWith({
    DateTime? selectedDate,
    PlaceChecklistSnapshot? snapshot,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PlaceChecklistState(
      selectedDate: selectedDate ?? this.selectedDate,
      snapshot: snapshot ?? this.snapshot,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final placeChecklistProvider = NotifierProvider.family<PlaceChecklistNotifier,
    PlaceChecklistState, PlaceChecklistFamilyArg>(PlaceChecklistNotifier.new);

class PlaceChecklistNotifier extends Notifier<PlaceChecklistState> {
  PlaceChecklistNotifier(this.arg);

  final PlaceChecklistFamilyArg arg;
  String? _loadedFrom;
  String? _loadedTo;

  PlaceChecklistRepository get _repo =>
      ref.read(placeChecklistRepositoryProvider);

  @override
  PlaceChecklistState build() {
    final today = scheduleDateOnly(DateTime.now());
    Future.microtask(load);
    return PlaceChecklistState(
      selectedDate: today,
      snapshot: null,
      isLoading: true,
    );
  }

  ({String from, String to}) _fetchRangeFor(DateTime center) {
    final day = scheduleDateOnly(center);
    final from = scheduleDateKey(
      day.subtract(const Duration(days: kChecklistFetchPaddingDays)),
    );
    final to = scheduleDateKey(
      day.add(const Duration(days: kChecklistFetchPaddingDays)),
    );
    return (from: from, to: to);
  }

  Future<void> load() async {
    final pid = arg.pid;
    if (pid <= 0) {
      state = state.copyWith(
        isLoading: false,
        snapshot: PlaceChecklistSnapshot(
          placeId: pid,
          items: const [],
          deferrals: const [],
        ),
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final range = _fetchRangeFor(state.selectedDate);
      final snap = await _repo.fetchForPlace(
        pid,
        from: range.from,
        to: range.to,
      );
      _loadedFrom = range.from;
      _loadedTo = range.to;
      state = state.copyWith(snapshot: snap, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: unwrapHttpClientException(e)?.message ?? '체크리스트를 불러오지 못했습니다.',
      );
    }
  }

  void selectDate(DateTime day) {
    final next = scheduleDateOnly(day);
    state = state.copyWith(selectedDate: next, clearError: true);
    final key = scheduleDateKey(next);
    final covered = _loadedFrom != null &&
        _loadedTo != null &&
        key.compareTo(_loadedFrom!) >= 0 &&
        key.compareTo(_loadedTo!) <= 0;
    if (!covered) {
      Future.microtask(load);
    }
  }

  void shiftDate(int days) {
    selectDate(state.selectedDate.add(Duration(days: days)));
  }

  Future<void> toggleChecked(PlaceChecklistItem item) async {
    if (item.isDeferred) return;
    final nextStatus = item.isChecked
        ? PlaceChecklistItemStatus.active
        : PlaceChecklistItemStatus.checked;
    await _upsert(item.copyWith(status: nextStatus));
  }

  Future<void> addItem({
    required String title,
    required String processGroup,
  }) async {
    final snap = state.snapshot;
    if (snap == null) return;
    final key = state.selectedDateKey;
    final dayItems = snap.itemsForDate(key);
    final sort = dayItems.isEmpty
        ? 0
        : dayItems.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    await _upsert(
      PlaceChecklistItem(
        id: '',
        workDate: key,
        title: title,
        processGroup: processGroup,
        sortOrder: sort,
      ),
    );
  }

  Future<void> updateItem(PlaceChecklistItem item) async {
    await _upsert(item);
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _repo.deleteItem(placeId: arg.pid, itemId: itemId);
      await load();
    } catch (e) {
      state = state.copyWith(
        error: unwrapHttpClientException(e)?.message ?? '삭제에 실패했습니다.',
      );
    }
  }

  Future<void> deferItem({
    required String itemId,
    String reason = '',
    String? toDate,
  }) async {
    final snap = state.snapshot;
    if (snap != null) {
      for (final item in snap.items) {
        if (item.id == itemId && item.isChecked) {
          state = state.copyWith(
            error: '완료된 항목은 미룰 수 없습니다. 체크를 해제한 뒤 다시 시도해 주세요.',
          );
          return;
        }
      }
    }
    final target =
        toDate ?? placeChecklistDefaultDeferToDate(state.selectedDateKey);
    try {
      await _repo.deferItem(
        placeId: arg.pid,
        itemId: itemId,
        toDate: target,
        reason: reason,
      );
      await load();
    } catch (e) {
      state = state.copyWith(
        error: unwrapHttpClientException(e)?.message ?? '미루기에 실패했습니다.',
      );
    }
  }

  Future<void> _upsert(PlaceChecklistItem item) async {
    try {
      await _repo.upsertItem(placeId: arg.pid, item: item);
      await load();
    } catch (e) {
      state = state.copyWith(
        error: unwrapHttpClientException(e)?.message ?? '저장에 실패했습니다.',
      );
    }
  }
}
