import 'dart:async' show Timer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:w0001/data/datasources/remote/daily_quotes_api.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/daily_quote_models.dart';
import 'package:w0001/data/repository/daily_quote_repository_impl.dart';
import 'package:w0001/domain/repository/daily_quote_repository.dart';

final dailyQuoteRepositoryProvider = Provider<DailyQuoteRepository>((ref) {
  return DailyQuoteRepositoryImpl(DailyQuotesRemoteApi(AppHttpClient.I));
});

final todayDailyQuoteProvider =
    AsyncNotifierProvider<TodayDailyQuoteNotifier, TodayDailyQuote?>(
  TodayDailyQuoteNotifier.new,
);

class TodayDailyQuoteNotifier extends AsyncNotifier<TodayDailyQuote?> {
  Timer? _refreshTimer;

  @override
  Future<TodayDailyQuote?> build() async {
    ref.onDispose(() => _refreshTimer?.cancel());
    final today = await ref.read(dailyQuoteRepositoryProvider).getToday();
    _scheduleNextRefresh(today);
    return today;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(dailyQuoteRepositoryProvider).getToday(),
    );
    final today = state.value;
    if (today != null) _scheduleNextRefresh(today);
  }

  void _scheduleNextRefresh(TodayDailyQuote today) {
    _refreshTimer?.cancel();
    final now = DateTime.now();
    final fallback = DateTime(now.year, now.month, now.day + 1);
    final serverTime = today.nextRefreshAt?.toLocal();
    final target =
        serverTime != null && serverTime.isAfter(now) ? serverTime : fallback;
    final delay = target.difference(now) + const Duration(seconds: 1);
    _refreshTimer = Timer(delay, refresh);
  }
}

/// 대시보드 명언 카드 접힘/펼침 상태 — 화면 키('admin'/'worker')별 로컬 저장.
final dailyQuoteCardExpandedProvider =
    NotifierProvider.family<DailyQuoteCardExpandedNotifier, bool, String>(
  DailyQuoteCardExpandedNotifier.new,
);

class DailyQuoteCardExpandedNotifier extends Notifier<bool> {
  DailyQuoteCardExpandedNotifier(this.screenKey);

  final String screenKey;

  String get _prefsKey => 'daily_quote_card_expanded_$screenKey';

  @override
  bool build() {
    Future.microtask(_load);
    return true;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefsKey);
      if (saved != null && ref.mounted) state = saved;
    } catch (_) {
      // 로컬 저장 실패 시 기본값(펼침) 유지
    }
  }

  Future<void> toggle() => setExpanded(!state);

  Future<void> setExpanded(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {}
  }
}

class DailyQuoteAdminState {
  const DailyQuoteAdminState({
    this.items = const [],
    this.today,
    this.settings = const DailyQuoteSettings(),
    this.isLoading = true,
    this.isSaving = false,
    this.query = '',
    this.showInactive = true,
    this.error,
  });

  final List<DailyQuote> items;
  final TodayDailyQuote? today;
  final DailyQuoteSettings settings;
  final bool isLoading;
  final bool isSaving;
  final String query;
  final bool showInactive;
  final String? error;

  DailyQuoteAdminState copyWith({
    List<DailyQuote>? items,
    TodayDailyQuote? today,
    DailyQuoteSettings? settings,
    bool? isLoading,
    bool? isSaving,
    String? query,
    bool? showInactive,
    String? error,
    bool clearError = false,
  }) {
    return DailyQuoteAdminState(
      items: items ?? this.items,
      today: today ?? this.today,
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      query: query ?? this.query,
      showInactive: showInactive ?? this.showInactive,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final dailyQuoteAdminProvider =
    NotifierProvider<DailyQuoteAdminNotifier, DailyQuoteAdminState>(
  DailyQuoteAdminNotifier.new,
);

class DailyQuoteAdminNotifier extends Notifier<DailyQuoteAdminState> {
  DailyQuoteRepository get _repository =>
      ref.read(dailyQuoteRepositoryProvider);

  @override
  DailyQuoteAdminState build() {
    Future.microtask(load);
    return const DailyQuoteAdminState();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final results = await Future.wait<Object>([
        _repository.list(
          pageSize: 200,
          query: state.query,
          isActive: state.showInactive ? null : true,
        ),
        _repository.getToday(),
        _repository.getSettings(),
      ]);
      state = state.copyWith(
        items: (results[0] as DailyQuotePage).items,
        today: results[1] as TodayDailyQuote,
        settings: results[2] as DailyQuoteSettings,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: _message(error, '명언 정보를 불러오지 못했습니다.'),
      );
    }
  }

  Future<void> search(String query) async {
    state = state.copyWith(query: query);
    await load();
  }

  Future<void> setShowInactive(bool value) async {
    state = state.copyWith(showInactive: value);
    await load();
  }

  Future<bool> saveQuote(DailyQuote quote) async {
    return _runSaving(
      () async {
        await _repository.save(quote);
        await load(silent: true);
      },
      fallback: '명언을 저장하지 못했습니다.',
    );
  }

  Future<bool> deleteQuote(int id) async {
    return _runSaving(
      () async {
        await _repository.delete(id);
        await load(silent: true);
      },
      fallback: '명언을 삭제하지 못했습니다.',
    );
  }

  Future<bool> updateSettings(DailyQuoteSettings settings) async {
    return _runSaving(
      () async {
        final saved = await _repository.updateSettings(settings);
        state = state.copyWith(settings: saved);
      },
      fallback: '명언 표시 설정을 저장하지 못했습니다.',
    );
  }

  Future<bool> overrideToday({
    required String author,
    required String authorProfile,
    required String message,
  }) async {
    return _runSaving(
      () async {
        final today = await _repository.overrideToday(
          author: author,
          authorProfile: authorProfile,
          message: message,
        );
        state = state.copyWith(today: today);
        ref.invalidate(todayDailyQuoteProvider);
      },
      fallback: '오늘의 명언을 지정하지 못했습니다.',
    );
  }

  Future<bool> clearTodayOverride() async {
    return _runSaving(
      () async {
        final today = await _repository.clearTodayOverride();
        state = state.copyWith(today: today);
        ref.invalidate(todayDailyQuoteProvider);
      },
      fallback: '자동 명언으로 되돌리지 못했습니다.',
    );
  }

  Future<bool> _runSaving(
    Future<void> Function() action, {
    required String fallback,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await action();
      state = state.copyWith(isSaving: false, clearError: true);
      ref.invalidate(todayDailyQuoteProvider);
      return true;
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        error: _message(error, fallback),
      );
      return false;
    }
  }

  static String _message(Object error, String fallback) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? fallback;
    }
    return unwrapHttpClientException(error)?.message ?? fallback;
  }
}
